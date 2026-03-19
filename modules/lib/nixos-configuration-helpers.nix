{
  lib,
  self,
  config,
  inputs,
  withSystem,
  ...
}:
{
  flake.lib.nixos-configuration-helpers =
    let
      # Import shared utilities from lib.modules
      inherit (self.lib.modules)
        collectHomeModules
        collectPlatformSystemModules
        collectRequires
        ;

      # ============================================================================
      # SECTION 1: Home Manager User Configuration
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

          # Helper to coalesce null to default value (for nullable host user fields)
          orDefault = value: default: if value != null then value else default;

          # Get inheritHostFeatures, handling null from host config
          hostInheritFeatures = hostUser.baseline.inheritHostFeatures or null;
          inheritHostFeatures = orDefault hostInheritFeatures (envUser.baseline.inheritHostFeatures or false);

          # Aggregate exclusions from host features
          hostExclusions = lib.unique (lib.flatten (lib.catAttrs "excludes" allHostFeatures));

          # Aggregate user feature names from all sources, handling nulls from host config
          baselineFeatureNames = orDefault (envUser.baseline.features or null) [ ];
          envFeatureNames = orDefault (envUser.features or null) [ ];
          hostFeatureNames = orDefault (hostUser.features or null) [ ];
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

          # Process user features: filter and resolve dependencies using lib.modules
          filteredUserFeatures = lib.filter isNotExcluded userFeatureModules;
          userFeatureDeps = collectRequires config.flake.features filteredUserFeatures;
          userFeatures = filteredUserFeatures ++ userFeatureDeps;

          # Split host features into core (always included) and non-core (conditional)
          coreHostFeatures = lib.filter (f: isCore f && isNotExcluded f) allHostFeatures;
          nonCoreHostFeatures = lib.filter (f: !(isCore f) && isNotExcluded f) allHostFeatures;

          # Collect home modules from each source using lib.modules
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

          # Feature resolution: use precomputed features when possible,
          # or compute fresh when roles are overridden (e.g., for kexec builds)
          usePrecomputed = overrideRoles == null;

          # Get active feature names
          activeFeatures =
            if usePrecomputed then
              hostOptions.features
            else
              # Compute fresh for override scenarios using lib.modules
              self.lib.modules.computeActiveFeatures {
                featuresConfig = config.flake.features;
                rolesConfig = config.flake.roles;
                hostRoles = overrideRoles;
                hostFeatures = hostOptions.extra-features or [ ];
                hostExclusions = hostOptions.excluded-features or [ ];
              };

          # Get feature modules for home-manager and system module collection
          allHostFeatures = map (name: config.flake.features.${name}) activeFeatures;

          # Collect platform-appropriate system modules using lib.modules
          systemModules = collectPlatformSystemModules allHostFeatures hostOptions.system;

          # Compute enabled users (only those with enableUnixAccount = true)
          enabledUsers =
            let
              environmentUserNames = builtins.attrNames (environment.users or { });
              hostUserNames = builtins.attrNames (hostOptions.users or { });
              enabledUserNames = lib'.unique (environmentUserNames ++ hostUserNames);

              # Deep merge environment and host user attributes (host overrides environment)
              # Host user values are null by default, so we filter them out before merging
              mergeUserAttrs =
                userName:
                let
                  envUser = environment.users.${userName} or { };
                  hostUser = hostOptions.users.${userName} or { };

                  # Check if a value should be filtered (is considered "unset")
                  isUnset =
                    key: value:
                    value == null
                    || (
                      # For module types (configuration), empty {} means "not set"
                      key == "configuration" && lib'.isAttrs value && value == { }
                    )
                    || (
                      # For baseline, filter if all sub-fields are null
                      key == "baseline" && lib'.isAttrs value && lib'.all (v: v == null) (lib'.attrValues value)
                    );

                  # Recursively filter out unset values from host user config
                  filterUnset =
                    value:
                    if lib'.isAttrs value && !lib'.isDerivation value then
                      let
                        filtered = lib'.filterAttrs (k: v: !isUnset k v) value;
                      in
                      lib'.mapAttrs (_: filterUnset) filtered
                    else
                      value;

                  hostOverrides = filterUnset hostUser;
                in
                lib'.recursiveUpdate envUser hostOverrides;

              allUsers = lib'.genAttrs enabledUserNames mergeUserAttrs;
            in
            lib'.filterAttrs (_userName: user: user.enableUnixAccount or false) allUsers;

          # Common specialArgs passed to all system modules
          specialArgs = {
            inherit
              pkgs'
              inputs
              environment
              ;
            host = hostOptions;
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

          mergedExclusions = lib.unique ((hostOptions.excluded-features or [ ]) ++ kexecExclusions);

          modifiedHostOptions = hostOptions // {
            excluded-features = mergedExclusions;
            extra-features = [ ];
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
