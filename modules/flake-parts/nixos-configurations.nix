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
      nixos_modules = lib.custom.listModulesRec ../../legacy-modules/nixos;
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
              inherit inputs hostOptions;
              inherit (config) nodes;
              lib = extendedLibrary;
            };

            modules =
              nixos_modules
              ++ [ config.modules.nixos.base ]
              ++ (lib.optionals (hostOptions ? roles) (
                builtins.map (role: inputs.self.modules.nixos.${role}) (
                  lib.filter (role: lib.hasAttr role inputs.self.modules.nixos) hostOptions.roles
                )
              ))
              ++ chaotic_imports
              ++ (hostOptions.extra_modules)
              ++ [
                nixpkgs'.nixosModules.notDetected
                homeManager'.nixosModules.home-manager
                (inputs.self.modules.nixos."${hostname}" or { })
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
