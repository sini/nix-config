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
      # Skips features where the type key is missing or set to the default empty module
      collectTypedModules =
        type: lib.foldr (v: acc: if v.${type} or null != null then acc ++ [ v.${type} ] else acc) [ ];

      # Cross-platform system modules
      collectSystemModules = collectTypedModules "system";

      # Platform-specific system modules
      collectLinuxModules = collectTypedModules "linux";
      collectDarwinModules = collectTypedModules "darwin";

      # Home-manager modules (all platforms)
      collectHomeModules = collectTypedModules "home";

      # Collect all applicable system modules for a given platform
      # Includes: cross-platform (system) + platform-specific (linux/darwin)
      collectPlatformSystemModules =
        features: system:
        let
          isDarwin = lib.hasSuffix "-darwin" system;
          isLinux = lib.hasSuffix "-linux" system;

          # Cross-platform modules (always included)
          sharedModules = collectSystemModules features;

          # Platform-specific modules
          platformModules =
            if isLinux then
              collectLinuxModules features
            else if isDarwin then
              collectDarwinModules features
            else
              throw "Unsupported system architecture: ${system}";
        in
        sharedModules ++ platformModules;

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
          ...
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
          nonCoreHostHomeModules =
            if inheritHostFeatures then collectHomeModules nonCoreHostFeatures else [ ];
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
      # SECTION 5: Host Configuration Builders
      # ============================================================================

      # Prepare platform-agnostic host context (shared between NixOS and Darwin builders)
      prepareHostContext =
        {
          hostOptions,
          overrideRoles ? null,
        }:
        _system:
        let
          # Select package set (stable vs unstable)
          useUnstable = hostOptions.unstable or false;
          pkgs' = if useUnstable then inputs.nixpkgs-unstable else inputs.nixpkgs;
          lib' = pkgs'.lib;
          home-manager' = if useUnstable then inputs.home-manager-unstable else inputs.home-manager;

          # Load environment configuration
          environment = config.flake.environments.${hostOptions.environment};

          # Determine effective roles (allows override for specialized builds like kexec)
          effectiveRoles = if overrideRoles != null then overrideRoles else hostOptions.roles;

          # Resolve all features with dependencies
          allHostFeatures = getModulesForFeatures {
            hostRoles = effectiveRoles;
            hostFeatures = hostOptions.features or [ ];
            hostExclusions = hostOptions.exclude-features or [ ];
          };

          # Extract feature names and collect platform-appropriate system modules
          activeFeatures = lib.unique (map (f: f.name) allHostFeatures);
          systemModules = collectPlatformSystemModules allHostFeatures hostOptions.system;

          # Compute enabled users (only those with enableUnixAccount = true)
          enabledUsers =
            let
              environmentUserNames = builtins.attrNames (environment.users or { });
              hostUserNames = builtins.attrNames (hostOptions.users or { });
              enabledUserNames = lib'.unique (environmentUserNames ++ hostUserNames);
              allUsers = lib'.filterAttrs (userName: _: lib'.elem userName enabledUserNames) environment.users;
            in
            lib'.filterAttrs (_userName: user: user.enableUnixAccount or false) allUsers;

          # Common specialArgs passed to all system modules
          specialArgs = {
            inherit
              pkgs'
              inputs
              hostOptions
              environment
              activeFeatures
              ;
            users = enabledUsers;
            lib = lib';
          };

          # Home-manager user configuration module (shared between platforms)
          homeManagerUsersModule = {
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
          };
        in
        {
          inherit
            pkgs'
            lib'
            home-manager'
            environment
            allHostFeatures
            activeFeatures
            systemModules
            enabledUsers
            specialArgs
            homeManagerUsersModule
            ;
        };

      # Build a NixOS host configuration
      mkNixosHost =
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
            ctx = prepareHostContext { inherit hostOptions overrideRoles; } system;
          in
          ctx.lib'.nixosSystem {
            inherit system;
            inherit (ctx) specialArgs;

            modules =
              ctx.systemModules
              ++ [
                ctx.pkgs'.nixosModules.notDetected
                ctx.home-manager'.nixosModules.home-manager
              ]
              ++ (if skipHomeManager then [ ] else [ ctx.homeManagerUsersModule ])
              ++ hostOptions.extra_modules
              ++ extraModules
              ++ (if skipHostConfig then [ ] else [ hostOptions.systemConfiguration ]);
          }
        );

      # Build a Darwin (macOS) host configuration
      mkDarwinHost =
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
            ctx = prepareHostContext { inherit hostOptions overrideRoles; } system;
          in
          inputs.nix-darwin.lib.darwinSystem {
            inherit system;
            inherit (ctx) specialArgs;

            modules =
              ctx.systemModules
              ++ [
                ctx.home-manager'.darwinModules.home-manager
              ]
              ++ (if skipHomeManager then [ ] else [ ctx.homeManagerUsersModule ])
              ++ hostOptions.extra_modules
              ++ extraModules
              ++ (if skipHostConfig then [ ] else [ hostOptions.systemConfiguration ]);
          }
        );

      # ============================================================================
      # SECTION 6: Public API Functions
      # ============================================================================

      # Platform detection helpers
      isDarwin = lib.hasSuffix "-darwin";
      isLinux = lib.hasSuffix "-linux";

      # Build a host configuration, dispatching to NixOS or Darwin based on system architecture
      mkHost =
        _name: hostOptions:
        let
          builder =
            if isLinux hostOptions.system then
              mkNixosHost
            else if isDarwin hostOptions.system then
              mkDarwinHost
            else
              throw "Unsupported system architecture: ${hostOptions.system}";
        in
        builder {
          inherit hostOptions;
        };

      # Build a minimal kexec installer variant (Linux/NixOS only)
      mkHostKexec =
        name: hostOptions:
        let
          kexecExclusions = [
            "network-boot"
            "facter"
            "systemd-boot"
            "avahi"
            "power-mgmt"
            "ssd"
          ];

          mergedExclusions = lib.unique ((hostOptions.exclude-features or [ ]) ++ kexecExclusions);

          modifiedHostOptions = hostOptions // {
            exclude-features = mergedExclusions;
            features = [ ];
          };
        in
        mkNixosHost {
          hostOptions = modifiedHostOptions;
          overrideRoles = [ "kexec" ];
          skipHomeManager = true;
          skipHostConfig = true;
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
      inherit
        mkHost
        mkHostKexec
        mkNixosHost
        mkDarwinHost
        ;
    };
}
