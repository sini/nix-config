{
  self,
  inputs,
  withSystem,

  ...
}:
{
  flake =
    {
      config,
      lib,
      ...
    }:
    let
      inherit (lib)
        mapAttrs
        ;
      namespace = "custom";
      extendedLib = inputs.nixpkgs.lib.extend (_self: _super: import ../lib _self namespace);

      common_modules =
        extendedLib.${namespace}.listModulesRec (extendedLib.${namespace}.relativeToRoot "modules/common")
        ++ [
          inputs.agenix.nixosModules.default
          inputs.agenix-rekey.nixosModules.default
        ];

      nixos_modules =
        common_modules
        ++ extendedLib.${namespace}.listModulesRec (extendedLib.${namespace}.relativeToRoot "modules/nixos")
        ++ [
          inputs.nixos-facter-modules.nixosModules.facter
          inputs.disko.nixosModules.disko
        ];

      darwin_modules =
        common_modules
        ++ extendedLib.${namespace}.listModulesRec (
          extendedLib.${namespace}.relativeToRoot "modules/darwin"
        );

      mkNixOSConfigWith =
        {
          hostname,
          system,
          path,
          extraModules ? [ ],
        }:
        withSystem system (
          {
            pkgsets,
            pkgs,
            unstable,
            homeManager,
            ...
          }:
          pkgsets.nixpkgs.lib.nixosSystem rec {
            inherit system;
            specialArgs = {
              inherit
                inputs
                pkgsets
                pkgs
                unstable
                ;
              inherit (config) nodes;
              lib = extendedLib;
              namespace = "custom";
            };
            modules =
              extraModules
              ++ nixos_modules
              ++ [
                pkgsets.nixpkgs.nixosModules.notDetected
                homeManager.nixosModules.home-manager
                {
                  networking.hostName = hostname;
                }
              ]
              ++ extendedLib.${namespace}.listModulesRec path;
          }
        );

      mkDarwinConfigWith =
        {
          hostname,
          system,
          path,
          extraModules ? [ ],
        }:
        withSystem system (
          {
            pkgsets,
            pkgs,
            unstable,
            homeManager,
            ...
          }:
          inputs.nix-darwin.lib.darwinSystem rec {
            inherit system;
            specialArgs = {
              inherit
                pkgsets
                pkgs
                unstable
                ;
              lib = extendedLib;
              inherit (config) nodes;

              namespace = "custom";
              inputs = inputs // {
                inherit (pkgsets) nixpkgs;
              };
            };
            modules =
              extraModules
              ++ darwin_modules
              ++ [
                homeManager.darwinModules.home-manager
                {
                  networking.hostName = hostname;
                }
              ]
              ++ extendedLib.${namespace}.listModulesRec path;
          }
        );

      inherit (extendedLib.${namespace}) linuxHosts darwinHosts;
    in
    {
      nixosConfigurations = lib.attrsets.mergeAttrsList (
        builtins.map (_elem: {
          "${_elem.hostname}" = mkNixOSConfigWith { inherit (_elem) hostname system path; };
        }) linuxHosts
      );

      darwinConfigurations = lib.attrsets.mergeAttrsList (
        builtins.map (_elem: {
          "${_elem.hostname}" = mkDarwinConfigWith { inherit (_elem) hostname system path; };
        }) darwinHosts
      );

      # All nixosSystem instanciations are collected here, so that we can refer
      # to any system via nodes.<name>
      nodes = self.outputs.nixosConfigurations // self.outputs.darwinConfigurations;

      # Add a shorthand to easily target toplevel derivations
      "@" = mapAttrs (_: v: v.config.system.build.toplevel) self.outputs.nodes;
    };
}
