{
  self,
  inputs,
  withSystem,
  ...
}:
let
  inherit (self) lib; # override flake-parts' lib with your extended lib
in
{
  flake =
    {
      config,
      ...
    }:
    let
      inherit (lib)
        mapAttrs
        ;
      inherit (lib) listModulesRec linuxHosts darwinHosts;

      common_modules = listModulesRec ../modules/common ++ [
        inputs.agenix.nixosModules.default
        inputs.agenix-rekey.nixosModules.default

      ];

      nixos_modules =
        common_modules
        ++ listModulesRec ../modules/nixos
        ++ [
          inputs.nixos-facter-modules.nixosModules.facter
          inputs.disko.nixosModules.disko
          # inputs.chaotic.nixosModules.default # For unstable
          inputs.chaotic.nixosModules.nyx-cache
          inputs.chaotic.nixosModules.nyx-overlay
          inputs.chaotic.nixosModules.nyx-registry
          inputs.catppuccin.nixosModules.catppuccin
        ];

      darwin_modules = common_modules ++ listModulesRec ../modules/darwin;

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
                lib
                ;
              inherit (config) nodes;
            };
            modules =
              listModulesRec path
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
                lib
                ;
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
              ++ listModulesRec path;
          }
        );

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
