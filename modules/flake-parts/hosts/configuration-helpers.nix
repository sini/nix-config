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

      # Import user resolution from lib.users
      inherit (self.lib.users) resolveUsers;

      # Import feature settings resolution from lib.modules
      inherit (self.lib.modules) resolveFeatureSettings;

      # ============================================================================
      # SECTION 1: Home Manager User Configuration
      # ============================================================================

      makeHomeConfig =
        {
          resolvedUser,
          allHostFeatures,
          environment,
          hostOptions,
        }:
        let
          includeHostFeatures = resolvedUser.system.include-host-features or false;
          userExtraFeatures = resolvedUser.system.extra-features or [ ];
          userExclusions = resolvedUser.system.excluded-features or [ ];

          coreFeatureNames = self.lib.modules.coreFeatures;
          isCore = f: lib.elem f.name coreFeatureNames;

          coreHostFeatures = lib.filter isCore allHostFeatures;
          nonCoreHostFeatures = lib.filter (f: !(isCore f)) allHostFeatures;

          baseFeatures = coreHostFeatures ++ (if includeHostFeatures then nonCoreHostFeatures else [ ]);

          userFeatureModules = map (name: config.features.${name}) userExtraFeatures;

          allFeatures = baseFeatures ++ userFeatureModules;

          featureExclusions = lib.unique (lib.flatten (lib.catAttrs "excludes" allFeatures));
          allExclusions = lib.unique (featureExclusions ++ userExclusions);

          isNotExcluded = f: !(lib.elem f.name allExclusions);
          filteredFeatures = lib.filter isNotExcluded allFeatures;

          featureDeps = collectRequires config.features filteredFeatures;
          resolvedFeatures = filteredFeatures ++ featureDeps;

          homeModules = collectHomeModules resolvedFeatures;

          # Resolve per-user settings (feature defaults → env → host → user)
          userSettings = resolveFeatureSettings {
            activeFeatureNames = map (f: f.name) resolvedFeatures;
            featuresConfig = config.features;
            envSettings = environment.feature-settings or { };
            hostSettings = hostOptions.feature-settings or { };
            userSettings = resolvedUser.system.feature-settings or { };
          };
        in
        {
          imports = homeModules ++ [
            { _module.args.settings = userSettings; }
          ];
        };

      # ============================================================================
      # SECTION 3: Host Configuration Builders
      # ============================================================================

      prepareHostContext =
        {
          hostOptions,
          overrideFeatures ? null,
        }:
        _system:
        let
          channel = config.channels.${hostOptions.channel};
          pkgs' = channel.nixpkgs;
          lib' = pkgs'.lib;
          home-manager' = channel.home-manager;
          nix-darwin' = channel.nix-darwin;

          environment = config.environments.${hostOptions.environment};

          usePrecomputed = overrideFeatures == null;

          activeFeatures =
            if usePrecomputed then
              hostOptions.features
            else
              self.lib.modules.computeActiveFeatures {
                featuresConfig = config.features;
                hostFeatures = overrideFeatures;
                hostExclusions = hostOptions.excluded-features or [ ];
              };

          allHostFeatures = map (name: config.features.${name}) activeFeatures;

          systemModules = collectPlatformSystemModules allHostFeatures hostOptions.system;

          # Resolve all users via ACL
          canonicalUsers = config.users or { };
          groupDefs = config.groups or { };
          users = resolveUsers lib' canonicalUsers environment hostOptions groupDefs;

          # Resolve cluster for this host (null if host is not in any cluster)
          cluster = lib.findFirst (c: c.resolvedHosts ? ${hostOptions.hostname}) null (
            builtins.attrValues (config.clusters or { })
          );

          # Resolve feature settings (feature defaults → environment → host)
          settings = resolveFeatureSettings {
            activeFeatureNames = activeFeatures;
            featuresConfig = config.features;
            envSettings = environment.feature-settings or { };
            hostSettings = hostOptions.feature-settings or { };
          };

          enabledUsers = lib'.filterAttrs (_: u: u.system.enable or false) users;

          specialArgs = {
            inherit
              pkgs'
              inputs
              environment
              cluster
              users
              settings
              ;
            host = hostOptions // {
              users = {
                all = users;
                enabled = enabledUsers;
                enabledNames = builtins.attrNames enabledUsers;
              };
            };
            lib = lib';
            flakeLib = self.lib;
          };
          homeManagerUsersModule = {
            home-manager.users = lib'.mapAttrs (
              _username: resolvedUser:
              makeHomeConfig {
                inherit
                  resolvedUser
                  allHostFeatures
                  environment
                  hostOptions
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
            nix-darwin'
            environment
            allHostFeatures
            activeFeatures
            systemModules
            users
            specialArgs
            homeManagerUsersModule
            ;
        };

      mkNixosHost =
        {
          hostOptions,
          overrideFeatures ? null,
          skipHomeManager ? false,
          skipHostConfig ? false,
          extraModules ? [ ],
        }:
        withSystem hostOptions.system (
          { system, ... }:
          let
            ctx = prepareHostContext { inherit hostOptions overrideFeatures; } system;
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

      mkDarwinHost =
        {
          hostOptions,
          overrideFeatures ? null,
          skipHomeManager ? false,
          skipHostConfig ? false,
          extraModules ? [ ],
        }:
        withSystem hostOptions.system (
          { system, ... }:
          let
            ctx = prepareHostContext { inherit hostOptions overrideFeatures; } system;
          in
          ctx.nix-darwin'.lib.darwinSystem {
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
      # SECTION 4: Public API Functions
      # ============================================================================

      isDarwin = lib.hasSuffix "-darwin";
      isLinux = lib.hasSuffix "-linux";

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
          overrideFeatures = [ "kexec" ];
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
