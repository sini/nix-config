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
          coreFeatures = config.roles.core.features;

          # 2. Get features from additional roles defined on the host.
          additionalFeatures = lib.optionals (hostRoles != null) (
            lib.flatten (
              builtins.map (roleName: config.roles.${roleName}.features) (
                # Ensure the role actually exists before trying to access it.
                lib.filter (roleName: lib.hasAttr roleName config.roles) hostRoles
              )
            )
          );

          # 3. Combine core and additional feature names and deduplicate.
          allFeatureNames = lib.unique (coreFeatures ++ additionalFeatures);

        in
        allFeatureNames;

      # Helper function to gather modules from features (both from roles and direct host features)
      getModulesForFeatures =
        {
          hostRoles,
          hostFeatures ? [ ],
        }:
        let
          # 1. Get feature names from roles
          roleFeatureNames = getFeaturesForRoles hostRoles;

          # 2. Combine with direct host feature names and deduplicate
          allFeatureNames = lib.unique (roleFeatureNames ++ hostFeatures);

          # 3. Map feature names to actual feature modules
          allFeatures = builtins.map (name: config.features.${name}) allFeatureNames;

          # 4. Resolve dependencies for all features
          featureDeps = collectRequires config.features allFeatures;
          allFeaturesWithDeps = allFeatures ++ featureDeps;

        in
        allFeaturesWithDeps;

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

            # Get all feature modules (from roles + direct host features + dependencies)
            allHostFeatures = getModulesForFeatures {
              hostRoles = hostOptions.roles;
              hostFeatures = hostOptions.features or [ ];
            };

            # Get active feature names (including transitive dependencies)
            activeFeatures = lib.unique (builtins.map (f: f.name) allHostFeatures);

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
                hostHomeModules = collectHomeModules allHostFeatures;

                # Get user-specific features and modules
                userFeatures =
                  let
                    # Get user from environment and host users
                    envUser = environment.users.${username} or { };
                    hostUser = hostOptions.users.${username} or { };

                    # Combine features from environment and host
                    envFeatureNames = envUser.features or [ ];
                    hostFeatureNames = hostUser.features or [ ];
                    allUserFeatureNames = lib.unique (envFeatureNames ++ hostFeatureNames);

                    # Map to actual feature modules
                    userFeatureModules = builtins.map (name: config.features.${name}) allUserFeatureNames;

                    # Resolve dependencies
                    userFeatureDeps = collectRequires config.features userFeatureModules;
                    allUserFeatures = userFeatureModules ++ userFeatureDeps;
                  in
                  allUserFeatures;

                # Collect user-specific home modules
                userHomeModules = collectHomeModules userFeatures;

                # Get user-specific configuration
                userConfigs = [
                  (environment.users.${username}.configuration or { })
                  (hostOptions.users.${username}.configuration or { })
                ];
              in
              {
                imports = hostHomeModules ++ userHomeModules ++ userConfigs;
              };

          in
          lib'.nixosSystem {
            inherit system;

            specialArgs = {
              inherit
                pkgs'
                inputs
                hostOptions
                environment
                activeFeatures
                ;
              inherit (config) nodes;
              users =
                let
                  # Get user names from environment and host configuration
                  environmentUserNames = builtins.attrNames (environment.users or { });
                  hostUserNames = builtins.attrNames (hostOptions.users or { });

                  # Merge and deduplicate user lists
                  enabledUserNames = lib'.unique (environmentUserNames ++ hostUserNames);

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
                  # Configure Home Manager with feature-based modules
                  home-manager.users = lib'.mapAttrs makeHome (
                    let
                      # Get user names from environment and host configuration
                      environmentUserNames = builtins.attrNames (environment.users or { });
                      hostUserNames = builtins.attrNames (hostOptions.users or { });
                      enabledUserNames = lib'.unique (environmentUserNames ++ hostUserNames);
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
