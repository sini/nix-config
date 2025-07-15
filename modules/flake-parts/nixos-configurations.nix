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
      lib = inputs.nixpkgs.lib;
      unstableLib = inputs.nixpkgs-unstable.lib;
    in
    {
      homeConfigurations = { };
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
              inherit inputs hostOptions;
              inherit (config) nodes;
              lib = extendedLibrary;
            };

            modules =
              [ config.modules.nixos.role_core ]
              ++ (lib.optionals (hostOptions ? roles) (
                builtins.map (role: inputs.self.modules.nixos."role_${role}") (
                  lib.filter (role: lib.hasAttr "role_${role}" inputs.self.modules.nixos) hostOptions.roles
                )
              ))
              ++ chaotic_imports
              ++ (hostOptions.extra_modules)
              ++ [
                inputs.nur.modules.nixos.default
                #inputs.impermanence.nixosModules.impermanence
                nixpkgs'.nixosModules.notDetected
                homeManager'.nixosModules.home-manager
                (inputs.self.modules.nixos."host_${hostname}" or { })
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
