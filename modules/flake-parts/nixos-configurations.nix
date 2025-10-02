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

      inherit (self.lib.modules)
        collectNixosModules
        collectHomeModules
        collectRequires
        ;

      # Helper function to gather features from core and host-specific roles
      getFeaturesForRoles =
        hostRoles:
        let
          # 1. Start with the core features required for all systems.
          coreFeatures = config.role.core.features;

          # 2. Get features from additional roles defined on the host.
          additionalFeatures = lib.optionals (hostRoles != null) (
            lib.flatten (
              builtins.map (roleName: config.role.${roleName}.features) (
                # Ensure the role actually exists before trying to access it.
                lib.filter (roleName: lib.hasAttr roleName config.role) hostRoles
              )
            )
          );

          # 3. Combine core and additional feature names and deduplicate.
          allFeatureNames = lib.unique (coreFeatures ++ additionalFeatures);

        in
        allFeatureNames;

      # A dedicated function to build a single NixOS host configuration.
      # This encapsulates all the logic for one machine.
      mkHost =
        _: hostOptions:
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

            # Get features from roles and direct host features
            roleFeatureNames = getFeaturesForRoles hostOptions.roles;
            roleFeatures = builtins.map (name: config.features.${name}) roleFeatureNames;

            # Get direct host features and combine with role features
            directHostFeatures = hostOptions.features or [ ];
            combinedFeatures = roleFeatures ++ directHostFeatures;

            # Resolve dependencies for all features
            hostFeatureDeps = collectRequires config.features combinedFeatures;
            allHostFeatures = combinedFeatures ++ hostFeatureDeps;

            # Collect NixOS modules from features
            nixosModules = (collectNixosModules allHostFeatures);

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

            # Home Manager configuration for users
            makeHome =
              username: userSpec:
              let
                # Collect home modules from host features
                homeModules = collectHomeModules allHostFeatures;

                # Map user's homeModules to actual modules
                userHomeModules = builtins.map (
                  moduleName: config.modules.homeManager.${moduleName}
                ) userSpec.homeModules;
              in
              {
                imports = homeModules ++ userHomeModules;
              };

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

                  # Filter config.users to only include enabled users
                  enabledUsers = lib'.filterAttrs (userName: _: lib'.elem userName enabledUserNames) config.users;
                in
                enabledUsers;
              lib = lib'; # Pass the correct lib (stable or unstable) to modules.
            };

            modules =
              # Import modules from features
              nixosModules
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
                  networking.hostName = hostOptions.hostname;
                  networking.domain = environment.domain;
                  facter.reportPath = hostOptions.facts;
                  age.rekey.hostPubkey = hostOptions.public_key;

                  # Configure Home Manager with feature-based modules
                  home-manager.users = lib'.mapAttrs makeHome (
                    let
                      # Get users from environment and host configuration
                      environmentUsers = environment.users or [ ];
                      hostUsers = hostOptions.users or [ ];
                      enabledUserNames = lib'.unique (environmentUsers ++ hostUsers);
                      enabledUsers = lib'.filterAttrs (userName: _: lib'.elem userName enabledUserNames) config.users;
                    in
                    enabledUsers
                  );
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
