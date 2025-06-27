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
        lib.custom.listModulesRec (lib.custom.relativeToRoot "legacy-modules/nixos")
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
    in
    {
      nixosConfigurations = lib.mapAttrs (
        hostname: options:
        withSystem options.system (
          {
            pkgs,
            pkgs-stable,
            system,
            ...
          }:
          let
            nixpkgs' = if options.unstable then inputs.nixpkgs-unstable else inputs.nixpkgs;
            homeManager' = if options.unstable then inputs.home-manager-unstable else inputs.home-manager;
            extendedLibrary = if options.unstable then unstableLib else lib;
            pkgs' = if options.unstable then pkgs else pkgs-stable;
          in
          nixpkgs'.lib.nixosSystem {
            inherit system;
            pkgs = pkgs';

            specialArgs = {
              inherit inputs;
              inherit (config) nodes;
              nodeOptions = options;
              lib = extendedLibrary;
            };

            modules =
              nixos_modules
              ++ options.additional_modules
              ++ [
                nixpkgs'.nixosModules.notDetected
                homeManager'.nixosModules.home-manager
                (config.flake.modules.nixos."host_${hostname}" or { })
                {
                  networking.hostName = hostname;
                  facter.reportPath = options.facts;
                  age.rekey.hostPubkey = options.public_key;
                  node.deployment.targetHost = options.deployment.targetHost;
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
