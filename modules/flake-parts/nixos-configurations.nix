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
          hostExclusions ? [ ],
        }:
        let
          # 1. Get feature names from roles
          roleFeatureNames = getFeaturesForRoles hostRoles;

          # 2. Combine with direct host feature names and deduplicate
          allFeatureNames = lib.unique (roleFeatureNames ++ hostFeatures);

          # 3. Map feature names to actual feature modules
          allFeatures = builtins.map (name: config.features.${name}) allFeatureNames;

          # 4. Collect all exclusions from features and host-level exclusions
          featureExclusions = lib.flatten (lib.catAttrs "excludes" allFeatures);
          allExclusions = lib.unique (featureExclusions ++ hostExclusions);

          # 5. Filter out excluded features from the root set
          filteredFeatures = lib.filter (f: !(lib.elem f.name allExclusions)) allFeatures;

          # 6. Resolve dependencies for filtered features
          featureDeps = collectRequires config.features filteredFeatures;
          allFeaturesWithDeps = filteredFeatures ++ featureDeps;

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
              hostExclusions = hostOptions.exclude-features or [ ];
            };

            # Get active feature names (including transitive dependencies)
            activeFeatures = lib.unique (builtins.map (f: f.name) allHostFeatures);

            # Collect NixOS modules from features
            nixosModules = (collectNixosModules allHostFeatures);

            # Select the correct chaotic-nyx modules based on channel.
            # chaoticImports =
            #   if useUnstable then
            #     [ inputs.chaotic.nixosModules.default ]
            #   else
            #     [
            #       inputs.chaotic.nixosModules.nyx-cache
            #       inputs.chaotic.nixosModules.nyx-overlay
            #       inputs.chaotic.nixosModules.nyx-registry
            #     ];

            # Compute enabled users (used in specialArgs and home-manager)
            enabledUsers =
              let
                environmentUserNames = builtins.attrNames (environment.users or { });
                hostUserNames = builtins.attrNames (hostOptions.users or { });
                enabledUserNames = lib'.unique (environmentUserNames ++ hostUserNames);
              in
              lib'.filterAttrs (userName: _: lib'.elem userName enabledUserNames) config.users;

            # Home Manager configuration for users
            makeHome =
              username: userSpec:
              let
                # Get user contexts
                globalUser = config.users.${username} or { };
                envUser = environment.users.${username} or { };
                hostUser = hostOptions.users.${username} or { };
                inheritHostFeatures = globalUser.baseline.inheritHostFeatures or false;

                # Collect all exclusions (host + user features)
                hostExclusions = lib.unique (lib.flatten (lib.catAttrs "excludes" allHostFeatures));

                baselineFeatureNames = globalUser.baseline.features or [ ];
                envFeatureNames = envUser.features or [ ];
                hostFeatureNames = hostUser.features or [ ];
                allUserFeatureNames = lib.unique (baselineFeatureNames ++ envFeatureNames ++ hostFeatureNames);
                userFeatureModules = builtins.map (name: config.features.${name}) allUserFeatureNames;
                userOnlyExclusions = lib.unique (lib.flatten (lib.catAttrs "excludes" userFeatureModules));

                allExclusions = lib.unique (hostExclusions ++ userOnlyExclusions);

                # Build filter predicates
                coreRoleFeatureNames = config.roles.core.features;
                isCore = f: lib.elem f.name coreRoleFeatureNames;
                isNotExcluded = f: !(lib.elem f.name allExclusions);

                # Filter and process user features
                filteredUserFeatures = lib.filter isNotExcluded userFeatureModules;
                userFeatureDeps = collectRequires config.features filteredUserFeatures;
                userFeatures = filteredUserFeatures ++ userFeatureDeps;

                # Split host features into core and non-core, applying all exclusions
                coreHostFeatures = lib.filter (f: isCore f && isNotExcluded f) allHostFeatures;
                nonCoreHostFeatures = lib.filter (f: !(isCore f) && isNotExcluded f) allHostFeatures;

                # Collect home modules
                coreHomeModules = collectHomeModules coreHostFeatures;
                nonCoreHostHomeModules =
                  if inheritHostFeatures then collectHomeModules nonCoreHostFeatures else [ ];
                userHomeModules = collectHomeModules userFeatures;

                # User configurations
                userConfigs = [
                  (environment.users.${username}.configuration or { })
                  (hostOptions.users.${username}.configuration or { })
                ];
              in
              {
                imports = coreHomeModules ++ nonCoreHostHomeModules ++ userHomeModules ++ userConfigs;
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
              users = enabledUsers;
              lib = lib'; # Pass the correct lib (stable or unstable) to modules.
            };

            modules =
              # Import modules from features
              nixosModules
              # Add modules from external flakes and sources.
              # ++ chaoticImports
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
                  home-manager.users = lib'.mapAttrs makeHome enabledUsers;
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
