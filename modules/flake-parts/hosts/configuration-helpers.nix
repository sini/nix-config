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
        }:
        let
          includeHostFeatures = resolvedUser.system.include-host-features or true;
          userExtraFeatures = resolvedUser.system.extra-features or [ ];
          userExclusions = resolvedUser.system.excluded-features or [ ];

          coreFeatureNames = self.lib.modules.coreFeatures;
          isCore = f: lib.elem f.name coreFeatureNames;

          coreHostFeatures = lib.filter isCore allHostFeatures;
          nonCoreHostFeatures = lib.filter (f: !(isCore f)) allHostFeatures;

          baseFeatures = coreHostFeatures ++ (if includeHostFeatures then nonCoreHostFeatures else [ ]);

          # Validate user extra-features only reference features with home modules
          systemOnlyFeatures = lib.filter (
            name:
            let
              f = config.features.${name};
            in
            f.home == { } && (f.system != { } || f.linux != { } || f.darwin != { })
          ) userExtraFeatures;

          userFeatureModules =
            assert lib.assertMsg (systemOnlyFeatures == [ ])
              "User extra-features must have home modules. System-only features should be added to the host: ${lib.concatStringsSep ", " systemOnlyFeatures}";
            map (name: config.features.${name}) userExtraFeatures;

          allFeatures = baseFeatures ++ userFeatureModules;

          featureExclusions = lib.unique (lib.flatten (lib.catAttrs "excludes" allFeatures));
          allExclusions = lib.unique (featureExclusions ++ userExclusions);

          isNotExcluded = f: !(lib.elem f.name allExclusions);
          filteredFeatures = lib.filter isNotExcluded allFeatures;

          featureDeps = collectRequires config.features filteredFeatures;
          # Deduplicate by feature name — a feature can appear both directly and as a dependency
          resolvedFeatures =
            let
              all = filteredFeatures ++ featureDeps;
              seen =
                lib.foldl'
                  (
                    acc: f:
                    if lib.elem f.name acc.names then
                      acc
                    else
                      {
                        names = acc.names ++ [ f.name ];
                        features = acc.features ++ [ f ];
                      }
                  )
                  {
                    names = [ ];
                    features = [ ];
                  }
                  all;
            in
            seen.features;

          homeModules = collectHomeModules resolvedFeatures;

          # Resolve per-user settings (feature defaults → canonical → env → host user)
          usl =
            resolvedUser.system.userSettingsLayers or {
              canonical = { };
              env = { };
              host = { };
            };
          resolvedUserSettings = resolveFeatureSettings {
            settingsKey = "user-settings";
            activeFeatureNames = map (f: f.name) resolvedFeatures;
            featuresConfig = config.features;
            layers = [
              # Canonical user settings (lowest user priority)
              (
                { lib, ... }:
                {
                  config = lib.mapAttrs (_: v: lib.mapAttrs (_: lib.mkDefault) v) usl.canonical;
                }
              )
              # Environment user settings (middle)
              (
                { lib, ... }:
                {
                  config = lib.mapAttrs (_: v: lib.mapAttrs (_: lib.mkDefault) v) usl.env;
                }
              )
              # Host user settings (highest)
              (_: { config = usl.host; })
            ];
          };

          # Augment user with resolved settings
          augmentedUser = resolvedUser // {
            settings = resolvedUserSettings;
          };
        in
        {
          imports = homeModules ++ [
            { _module.args.user = augmentedUser; }
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
            layers = [
              (
                { lib, ... }:
                {
                  config = lib.mapAttrs (_: v: lib.mapAttrs (_: lib.mkDefault) v) (environment.settings or { });
                }
              )
              (_: { config = hostOptions.settings or { }; })
            ];
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
