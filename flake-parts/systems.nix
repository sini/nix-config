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
      extendedLib = inputs.nixpkgs.lib.extend (_self: _super: import ../lib _self);

      common_modules =
        extendedLib.custom.listModulesRec (extendedLib.custom.relativeToRoot "modules/common")
        ++ [
          inputs.agenix.nixosModules.default
          inputs.agenix-rekey.nixosModules.default

        ];

      nixos_modules =
        common_modules
        ++ extendedLib.custom.listModulesRec (extendedLib.custom.relativeToRoot "modules/nixos")
        ++ [
          inputs.nixos-facter-modules.nixosModules.facter
          inputs.disko.nixosModules.disko
          # inputs.chaotic.nixosModules.default # For unstable
          inputs.chaotic.nixosModules.nyx-cache
          inputs.chaotic.nixosModules.nyx-overlay
          inputs.chaotic.nixosModules.nyx-registry
          inputs.catppuccin.nixosModules.catppuccin
        ];

      darwin_modules =
        common_modules
        ++ extendedLib.custom.listModulesRec (extendedLib.custom.relativeToRoot "modules/darwin");

      mkNixOSConfigWith =
        {
          hostname,
          system,
          path,
          extraModules ? [ ],
        }:
        withSystem system (
          {
            pkgs,
            ...
          }:
          inputs.nixpkgs.lib.nixosSystem rec {
            inherit system pkgs;
            specialArgs = {
              inherit
                inputs
                ;
              inherit (config) nodes;
              lib = extendedLib;
            };
            modules =
              extendedLib.custom.listModulesRec path
              ++ extraModules
              ++ nixos_modules
              ++ [
                inputs.nixpkgs.nixosModules.notDetected
                inputs.home-manager.nixosModules.home-manager
                {
                  networking.hostName = hostname;
                  # Set the factor report to the provided path's facter.json file
                  facter.reportPath = path + "/facter.json";
                }
              ];
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
            pkgs,
            ...
          }:
          inputs.nix-darwin.lib.darwinSystem rec {
            inherit system pkgs;
            specialArgs = {
              inherit
                pkgs
                ;
              lib = extendedLib;
              inherit (config) nodes;

              inputs = inputs // {
                inherit (pkgs) nixpkgs;
              };
            };
            modules =
              extraModules
              ++ darwin_modules
              ++ [
                inputs.home-manager-darwin.darwinModules.home-manager
                {
                  networking.hostName = hostname;
                }
              ]
              ++ extendedLib.custom.listModulesRec path;
          }
        );

      inherit (extendedLib.custom) linuxHosts darwinHosts;
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
