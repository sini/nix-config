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
      ...
    }:
    let
      lib = inputs.nixpkgs.lib.extend (_self: _super: import ../../lib _self);
      unstableLib = inputs.nixpkgs-unstable.lib.extend (_self: _super: import ../../lib _self);
      nixos_modules =
        lib.custom.listModulesRec ../../legacy-modules/nixos
        ++ [

          inputs.catppuccin.nixosModules.catppuccin
        ]
        ++ [ inputs.self.modules.nixos.core ];
    in
    {
      nixosConfigurations = lib.mapAttrs (
        hostname: hostOptions:
        withSystem hostOptions.system (
          { system, ... }:
          let
            nixpkgs' = if hostOptions.unstable then inputs.nixpkgs-unstable else inputs.nixpkgs;
            homeManager' = if hostOptions.unstable then inputs.home-manager-unstable else inputs.home-manager;
            extendedLibrary = if hostOptions.unstable then unstableLib else lib;
            chaotic_imports =
              if hostOptions.unstable then
                [ inputs.chaotic.nixosModules.default ]
              else
                [
                  inputs.chaotic.nixosModules.nyx-cache
                  inputs.chaotic.nixosModules.nyx-overlay
                  inputs.chaotic.nixosModules.nyx-registry
                ];
          in
          nixpkgs'.lib.nixosSystem {
            inherit system;

            specialArgs = {
              inherit inputs;
              inherit (config) nodes;
              nodeOptions = hostOptions;
              lib = extendedLibrary;
            };

            modules =
              nixos_modules
              ++ chaotic_imports
              ++ hostOptions.additional_modules
              ++ [
                nixpkgs'.nixosModules.notDetected
                homeManager'.nixosModules.home-manager
                (config.flake.modules.nixos.hosts."${hostname}" or { })
                {
                  networking.hostName = hostname;
                  facter.reportPath = hostOptions.facts;
                  age.rekey.hostPubkey = hostOptions.public_key;
                }
              ];
          }
        )
      ) config.hosts;

      # All nixosSystem instanciations are collected here, so that we can refer
      # to any system via nodes.<name>
      nodes = self.outputs.nixosConfigurations;
    };
}
