{
  lib,
  config,
  inputs,
  withSystem,
  ...
}:
let
  inherit (lib)
    elem
    filter
    head
    tail
    ;
in
{
  flake.lib.nixos-configuration-helpers =
    let
      # ============================================================================
      # SECTION 1: Module Collection Utilities
      # ============================================================================
      # These functions extract typed modules (nixos/home) from feature definitions

      # Generic collector for modules of a specific type from feature list
      collectTypedModules =
        type: lib.foldr (v: acc: if v.${type} or null != null then acc ++ [ v.${type} ] else acc) [ ];

      collectNixosModules = collectTypedModules "nixos";
      collectHomeModules = collectTypedModules "home";

      # ============================================================================
      # SECTION 2: Feature Dependency Resolution
      # ============================================================================
      # Resolves transitive dependencies between features while respecting exclusions

      # Recursively collect all dependencies for a set of root features
      # Returns only the dependencies (not the roots themselves)
      # Exclusions are propagated through the dependency tree
      collectRequires =
        features: roots:
        let
          rootNames = lib.catAttrs "name" roots;
          initialExclusions = lib.unique (lib.flatten (lib.catAttrs "excludes" roots));

          # Depth-first traversal of dependency tree
          traverseDependencies =
            visited: toVisit: exclusions:
            if toVisit == [ ] then
              visited
            else
              let
                current = head toVisit;
                remaining = tail toVisit;
                isExcluded = elem current.name exclusions;
                isVisited = elem current.name (map (v: v.name) visited);
              in
              # Skip if excluded or already visited
              if isExcluded || isVisited then
                traverseDependencies visited remaining exclusions
              else
                let
                  # Accumulate exclusions from current feature
                  updatedExclusions = lib.unique (exclusions ++ (current.excludes or [ ]));

                  # Resolve dependencies, filtering out excluded ones
                  dependencyNames = filter (name: !(elem name updatedExclusions)) (current.requires or [ ]);
                  dependencies = map (name: features.${name}) dependencyNames;

                  # Recursively process dependencies, then add current feature
                  visitedWithDeps = traverseDependencies visited dependencies updatedExclusions;
                in
                traverseDependencies (visitedWithDeps ++ [ current ]) remaining updatedExclusions;

          # Initial traversal (includes roots in result)
          resultWithRoots = traverseDependencies [ ] roots initialExclusions;

          # Collect ALL exclusions from entire tree for final filtering
          allExclusions = lib.unique (lib.flatten (lib.catAttrs "excludes" (roots ++ resultWithRoots)));

          # Filter out excluded features and remove roots (they're already included elsewhere)
          dependenciesOnly = filter (
            v: !(elem v.name allExclusions) && !(elem v.name rootNames)
          ) resultWithRoots;
        in
        dependenciesOnly;

      # ============================================================================
      # SECTION 3: Feature Aggregation from Roles
      # ============================================================================
      # Builds the complete feature set from role definitions

      # Aggregate feature names from core role and additional host-specific roles
      getFeaturesForRoles =
        hostRoles:
        let
          coreFeatures = config.flake.roles.core.features;

          additionalFeatures = lib.optionals (hostRoles != null) (
            lib.flatten (
              map (roleName: config.flake.roles.${roleName}.features) (
                lib.filter (roleName: lib.hasAttr roleName config.flake.roles) hostRoles
              )
            )
          );

          allFeatureNames = lib.unique (coreFeatures ++ additionalFeatures);
        in
        allFeatureNames;

      # Resolve complete feature set for a host (roles + direct features + dependencies)
      # Returns feature modules with all dependencies resolved and exclusions applied
      getModulesForFeatures =
        {
          hostRoles,
          hostFeatures ? [ ],
          hostExclusions ? [ ],
        }:
        let
          # Step 1: Aggregate feature names from all sources
          roleFeatureNames = getFeaturesForRoles hostRoles;
          allFeatureNames = lib.unique (roleFeatureNames ++ hostFeatures);

          # Step 2: Convert names to feature modules
          allFeatures = map (name: config.flake.features.${name}) allFeatureNames;

          # Step 3: Collect and merge all exclusions
          featureExclusions = lib.flatten (lib.catAttrs "excludes" allFeatures);
          allExclusions = lib.unique (featureExclusions ++ hostExclusions);

          # Step 4: Filter out excluded features
          filteredFeatures = lib.filter (f: !(lib.elem f.name allExclusions)) allFeatures;

          # Step 5: Resolve transitive dependencies
          featureDeps = collectRequires config.flake.features filteredFeatures;

          # Step 6: Combine roots and dependencies
          allFeaturesWithDeps = filteredFeatures ++ featureDeps;
        in
        allFeaturesWithDeps;

      # ============================================================================
      # SECTION 4: Home Manager User Configuration
      # ============================================================================
      # Builds home-manager configuration for individual users

      # Create home-manager configuration for a specific user
      # Combines: baseline features + environment features + host features + user-specific features
      # Respects: host exclusions, user exclusions, and inheritHostFeatures setting
      makeHomeConfig =
        {
          username,
          environment,
          hostOptions,
          allHostFeatures,
        }:
        let
          # Get user specifications from environment and host
          envUser = environment.users.${username} or { };
          hostUser = hostOptions.users.${username} or { };
          inheritHostFeatures = envUser.baseline.inheritHostFeatures or false;

          # Aggregate exclusions from host features
          hostExclusions = lib.unique (lib.flatten (lib.catAttrs "excludes" allHostFeatures));

          # Aggregate user feature names from all sources
          baselineFeatureNames = envUser.baseline.features or [ ];
          envFeatureNames = envUser.features or [ ];
          hostFeatureNames = hostUser.features or [ ];
          allUserFeatureNames = lib.unique (baselineFeatureNames ++ envFeatureNames ++ hostFeatureNames);

          # Convert to feature modules and collect user-specific exclusions
          userFeatureModules = map (name: config.flake.features.${name}) allUserFeatureNames;
          userOnlyExclusions = lib.unique (lib.flatten (lib.catAttrs "excludes" userFeatureModules));

          # Merge all exclusions
          allExclusions = lib.unique (hostExclusions ++ userOnlyExclusions);

          # Helper predicates for filtering
          coreRoleFeatureNames = config.flake.roles.core.features;
          isCore = f: lib.elem f.name coreRoleFeatureNames;
          isNotExcluded = f: !(lib.elem f.name allExclusions);

          # Process user features: filter and resolve dependencies
          filteredUserFeatures = lib.filter isNotExcluded userFeatureModules;
          userFeatureDeps = collectRequires config.flake.features filteredUserFeatures;
          userFeatures = filteredUserFeatures ++ userFeatureDeps;

          # Split host features into core (always included) and non-core (conditional)
          coreHostFeatures = lib.filter (f: isCore f && isNotExcluded f) allHostFeatures;
          nonCoreHostFeatures = lib.filter (f: !(isCore f) && isNotExcluded f) allHostFeatures;

          # Collect home modules from each source
          coreHomeModules = collectHomeModules coreHostFeatures;
          nonCoreHostHomeModules = if inheritHostFeatures then collectHomeModules nonCoreHostFeatures else [ ];
          userHomeModules = collectHomeModules userFeatures;

          # User-specific configuration overrides
          userConfigs = [
            (envUser.configuration or { })
            (hostUser.configuration or { })
          ];
        in
        {
          imports = coreHomeModules ++ nonCoreHostHomeModules ++ userHomeModules ++ userConfigs;
        };

      # ============================================================================
      # SECTION 5: Host Configuration Builder
      # ============================================================================
      # Core logic for building NixOS system configurations

      # Shared implementation for mkHost and mkHostKexec
      # Allows overriding roles and selectively skipping components for specialized builds
      mkHostCommon =
        {
          hostOptions,
          overrideRoles ? null,
          skipHomeManager ? false,
          skipHostConfig ? false,
          extraModules ? [ ],
        }:
        withSystem hostOptions.system (
          { system, ... }:
          let
            # Step 1: Select package set (stable vs unstable)
            useUnstable = hostOptions.unstable or false;
            pkgs' = if useUnstable then inputs.nixpkgs-unstable else inputs.nixpkgs;
            lib' = pkgs'.lib;
            home-manager' = if useUnstable then inputs.home-manager-unstable else inputs.home-manager;

            # Step 2: Load environment configuration
            environment = config.flake.environments.${hostOptions.environment};

            # Step 3: Determine effective roles (allows override for specialized builds like kexec)
            effectiveRoles = if overrideRoles != null then overrideRoles else hostOptions.roles;

            # Step 4: Resolve all features with dependencies
            allHostFeatures = getModulesForFeatures {
              hostRoles = effectiveRoles;
              hostFeatures = hostOptions.features or [ ];
              hostExclusions = hostOptions.exclude-features or [ ];
            };

            # Step 5: Extract feature names and NixOS modules
            activeFeatures = lib.unique (map (f: f.name) allHostFeatures);
            nixosModules = collectNixosModules allHostFeatures;

            # Step 6: Compute enabled users (only those with enableUnixAccount = true)
            enabledUsers =
              let
                environmentUserNames = builtins.attrNames (environment.users or { });
                hostUserNames = builtins.attrNames (hostOptions.users or { });
                enabledUserNames = lib'.unique (environmentUserNames ++ hostUserNames);
                allUsers = lib'.filterAttrs (userName: _: lib'.elem userName enabledUserNames) environment.users;
              in
              lib'.filterAttrs (_userName: user: user.enableUnixAccount or false) allUsers;
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
              inherit (config.flake) nodes;
              users = enabledUsers;
              lib = lib'; # Pass the correct lib (stable or unstable) to modules.
            };

            modules =
              # Import modules from features
              nixosModules
              # Add modules from external flakes and sources
              ++ [
                pkgs'.nixosModules.notDetected
                # Always include home-manager NixOS module for option definitions
                home-manager'.nixosModules.home-manager
              ]
              # Conditionally configure home-manager users if not skipped
              ++ (
                if skipHomeManager then
                  [ ]
                else
                  [
                    {
                      # Configure Home Manager with feature-based modules
                      home-manager.users = lib'.mapAttrs (
                        username: _userSpec:
                        makeHomeConfig {
                          inherit
                            username
                            environment
                            hostOptions
                            allHostFeatures
                            lib'
                            ;
                        }
                      ) enabledUsers;
                    }
                  ]
              )
              # Add any extra modules defined directly on the host
              ++ hostOptions.extra_modules
              # Add extra modules passed to this function
              ++ extraModules
              # Conditionally add the host's primary configuration file
              ++ (if skipHostConfig then [ ] else [ hostOptions.nixosConfiguration ]);
          }
        );

      # ============================================================================
      # SECTION 6: Public API Functions
      # ============================================================================

      # Build a standard NixOS host configuration
      # This is the primary function for creating host system configurations
      mkHost =
        _name: hostOptions:
        mkHostCommon {
          inherit hostOptions;
          overrideRoles = null;
          skipHomeManager = false;
          skipHostConfig = false;
          extraModules = [ ];
        };

      # Build a minimal kexec installer variant of a host configuration
      # This creates a stripped-down system suitable for network-based installation
      # - Uses only the "kexec" role (minimal feature set)
      # - Excludes hardware-specific and installer-incompatible features
      # - Skips home-manager (not needed for installer)
      # - Skips host-specific hardware configuration
      mkHostKexec =
        name: hostOptions:
        let
          # Features incompatible with or unnecessary for kexec installer environment
          kexecExclusions = [
            "network-boot" # Host-specific network boot settings
            "facter" # Hardware detection not needed for installer
            "systemd-boot" # Bootloader not needed for installer
            "avahi" # Service discovery not needed for installer
            "power-mgmt" # Power management not needed for installer
            "ssd" # SSD optimizations not needed for installer
          ];

          # Merge installer exclusions with any existing host exclusions
          mergedExclusions = lib.unique ((hostOptions.exclude-features or [ ]) ++ kexecExclusions);

          # Create modified host options for installer build
          modifiedHostOptions = hostOptions // {
            exclude-features = mergedExclusions;
            features = [ ]; # Clear all host-specific features for minimal build
          };
        in
        mkHostCommon {
          hostOptions = modifiedHostOptions;
          overrideRoles = [ "kexec" ]; # Use only kexec role
          skipHomeManager = true; # No user home configurations in installer
          skipHostConfig = true; # Skip hardware-specific configuration
          # Set installer-specific hostname
          extraModules = [
            (
              { lib, ... }:
              {
                networking.hostName = lib.mkForce "${name}";
              }
            )
          ];
        };
    in
    {
      inherit mkHost mkHostKexec;
    };
}
