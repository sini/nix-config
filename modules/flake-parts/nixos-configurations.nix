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
      # This is set due to a regression in agenix-rekey that checks for homeConfigurations when its called from home-manager
      homeConfigurations = { };
      nixosConfigurations = lib.mapAttrs (
        hostname: hostOptions:
        withSystem hostOptions.system (
          { system, ... }:
          let
            nixpkgs' = if hostOptions.unstable then inputs.nixpkgs-unstable else inputs.nixpkgs;
            homeManager' = if hostOptions.unstable then inputs.home-manager-unstable else inputs.home-manager;
            extendedLibrary = if hostOptions.unstable then unstableLib else lib;
            environment = config.environments.${hostOptions.environment};
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
              inherit inputs hostOptions environment;
              inherit (config) nodes;
              users = config.user;
              lib = extendedLibrary;
            };

            modules =
              let
                # Collect all nixos module names from core and additional roles
                allNixosModuleNames =
                  config.role.core.nixosModules
                  ++ (lib.optionals (hostOptions ? roles) (
                    lib.flatten (
                      builtins.map (roleName: config.role.${roleName}.nixosModules) (
                        lib.filter (role: lib.hasAttr role config.role) hostOptions.roles
                      )
                    )
                  ));
                # Remove duplicates and convert to actual modules
                uniqueNixosModules = builtins.map (moduleName: config.modules.nixos.${moduleName}) (
                  lib.unique allNixosModuleNames
                );
              in
              uniqueNixosModules
              ++ chaotic_imports
              ++ (hostOptions.extra_modules)
              ++ [
                inputs.nur.modules.nixos.default
                #inputs.impermanence.nixosModules.impermanence
                nixpkgs'.nixosModules.notDetected
                homeManager'.nixosModules.home-manager
                hostOptions.nixosConfiguration
                {
                  networking.hostName = hostname;
                  networking.domain = environment.domain;
                  facter.reportPath = hostOptions.facts;
                  age.rekey.hostPubkey = hostOptions.public_key;

                  # Home Manager configuration
                  home-manager.users.${config.meta.user.username}.imports =
                    let
                      # Collect all home manager module names from core and additional roles
                      allHomeModuleNames =
                        config.role.core.homeModules
                        ++ (lib.optionals (hostOptions ? roles) (
                          lib.flatten (
                            builtins.map (roleName: config.role.${roleName}.homeModules) (
                              lib.filter (role: lib.hasAttr role config.role) hostOptions.roles
                            )
                          )
                        ));
                      # Remove duplicates and convert to actual modules
                      uniqueHomeModules = builtins.map (moduleName: config.modules.homeManager.${moduleName}) (
                        lib.unique allHomeModuleNames
                      );
                    in
                    uniqueHomeModules;
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
