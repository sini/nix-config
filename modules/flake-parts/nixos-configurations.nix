{
  self,
  inputs,
  withSystem,
  ...
}:
{
  flake =
    { config, ... }:
    let
      lib = inputs.nixpkgs.lib;

      # Helper function to gather and deduplicate modules from core and host-specific roles.
      # This avoids repeating the same logic for both nixos and home-manager modules.
      getModulesForRoles =
        { roleType, hostRoles }:
        let
          # e.g., "nixosModules" or "homeManagerModules"
          moduleAttrName = "${roleType}Modules";
          # e.g., config.modules.nixos or config.modules.homeManager
          modulePath = config.modules.${roleType};

          # 1. Start with the core modules required for all systems.
          coreModules = config.role.core.${moduleAttrName};

          # 2. Get modules from additional roles defined on the host.
          additionalModules = lib.optionals (hostRoles != null) (
            lib.flatten (
              builtins.map (roleName: config.role.${roleName}.${moduleAttrName}) (
                # Ensure the role actually exists before trying to access it.
                lib.filter (roleName: lib.hasAttr roleName config.role) hostRoles
              )
            )
          );

          # 3. Combine core and additional module names.
          allModuleNames = coreModules ++ additionalModules;

        in
        # 4. Remove duplicate names and map them to their actual module files.
        builtins.map (moduleName: modulePath.${moduleName}) (lib.unique allModuleNames);

      # A dedicated function to build a single NixOS host configuration.
      # This encapsulates all the logic for one machine.
      mkHost =
        hostname: hostOptions:
        withSystem hostOptions.system (
          { system, ... }:
          let
            # Determine whether to use stable or unstable packages based on the host's options.
            useUnstable = hostOptions.unstable or false;
            pkgs' = if useUnstable then inputs.nixpkgs-unstable else inputs.nixpkgs;
            lib' = pkgs'.lib;
            home-manager' = if useUnstable then inputs.home-manager-unstable else inputs.home-manager;

            # Select the correct environment configuration (e.g., prod, dev).
            environment = config.environments.${hostOptions.environment};

            # Select the correct chaotic-nyx modules based on channel.
            chaoticImports =
              if useUnstable then
                [ inputs.chaotic.nixosModules.default ]
              else
                [
                  inputs.chaotic.nixosModules.nyx-cache
                  inputs.chaotic.nixosModules.nyx-overlay
                  inputs.chaotic.nixosModules.nyx-registry
                ];

          in
          lib'.nixosSystem {
            inherit system;

            specialArgs = {
              inherit inputs hostOptions environment;
              inherit (config) nodes;
              users =
                let
                  # Get users from environment and host configuration
                  environmentUsers = environment.users or [ ];
                  hostUsers = hostOptions.users or [ ];

                  # Merge and deduplicate user lists
                  enabledUserNames = lib'.unique (environmentUsers ++ hostUsers);

                  # Filter config.user to only include enabled users
                  enabledUsers = lib'.filterAttrs (userName: _: lib'.elem userName enabledUserNames) config.user;
                in
                enabledUsers;
              lib = lib'; # Pass the correct lib (stable or unstable) to modules.
            };

            modules =
              # Import modules defined by the host's roles.
              (getModulesForRoles {
                roleType = "nixos";
                hostRoles = hostOptions.roles;
              })
              # Add modules from external flakes and sources.
              ++ chaoticImports
              ++ [
                inputs.nur.modules.nixos.default
                # inputs.impermanence.nixosModules.impermanence # Uncomment to use
                pkgs'.nixosModules.notDetected
                home-manager'.nixosModules.home-manager
              ]
              # Add any extra modules defined directly on the host.
              ++ hostOptions.extra_modules
              # Add the host's primary configuration file.
              ++ [ hostOptions.nixosConfiguration ]
              # Finally, apply machine-specific settings and configure Home Manager.
              ++ [
                {
                  networking.hostName = hostname;
                  networking.domain = environment.domain;
                  facter.reportPath = hostOptions.facts;
                  age.rekey.hostPubkey = hostOptions.public_key;

                }
              ];
          }
        );
    in
    {
      # This is set due to a regression in agenix-rekey that checks for homeConfigurations.
      homeConfigurations = { };

      # Build all NixOS configurations by applying the mkHost function to each host.
      nixosConfigurations = lib.mapAttrs mkHost config.hosts;

      # Allow systems to refer to each other via nodes.<name>
      nodes = self.outputs.nixosConfigurations;
    };
}
