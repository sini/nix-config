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
      extendedLib = inputs.nixpkgs.lib.extend (_self: _super: import ../../lib _self);

      nixos_modules =
        extendedLib.custom.listModulesRec (extendedLib.custom.relativeToRoot "legacy-modules/nixos")
        ++ [
          inputs.nixos-facter-modules.nixosModules.facter
          inputs.disko.nixosModules.disko
          # inputs.chaotic.nixosModules.default # For unstable
          inputs.chaotic.nixosModules.nyx-cache
          inputs.chaotic.nixosModules.nyx-overlay
          inputs.chaotic.nixosModules.nyx-registry
          inputs.catppuccin.nixosModules.catppuccin
        ]
        ++ [ inputs.self.modules.nixos.core ];

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
          inputs.nixpkgs.lib.nixosSystem {
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

      inherit (extendedLib.custom) linuxHosts;
    in
    {
      nixosConfigurations = lib.attrsets.mergeAttrsList (
        builtins.map (_elem: {
          "${_elem.hostname}" = mkNixOSConfigWith { inherit (_elem) hostname system path; };
        }) linuxHosts
      );

      # All nixosSystem instanciations are collected here, so that we can refer
      # to any system via nodes.<name>
      nodes = self.outputs.nixosConfigurations;

      # Add a shorthand to easily target toplevel derivations
      "@" = mapAttrs (_: v: v.config.system.build.toplevel) self.outputs.nodes;
    };
}
