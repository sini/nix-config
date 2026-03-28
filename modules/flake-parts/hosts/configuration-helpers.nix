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
      # Import shared utilities from lib.modules and lib.collection
      inherit (self.lib.collection)
        collectPlatformSystemModulesNew
        collectPlatformHomeModules
        ;

      # Import user resolution from lib.users
      inherit (self.lib.users) resolveUsers;

      # Import feature settings resolution from lib.modules
      inherit (self.lib.modules) resolveFeatureSettings;

      # Import resolver for provider resolution
      inherit (self.lib.resolver) resolveFeatures;

      # ============================================================================
      # SECTION 1: Home Manager User Configuration
      # ============================================================================

      makeHomeConfig =
        {
          resolvedUser,
          allHostFeatures,
          activeProviders ? [ ],
          system ? "x86_64-linux",
          fullContext ? { },
          dispatchableArgs ? [ ],
        }:
        let
          includeHostFeatures = resolvedUser.system.include-host-features or true;
          userExtraFeatures = resolvedUser.system.extra-features or [ ];
          userExclusions = resolvedUser.system.excluded-features or [ ];

          # Combine host features with user-specific features
          userExtraFeatureNames = map (name: name) userExtraFeatures;

          # Validate user extra-features have home modules
          systemOnlyFeatures = lib.filter (
            name:
            let f = config.features.${name};
            in f.home == {} && (f.system or {} != {} || f.linux != {} || f.darwin != {} || f.os or {} != {})
          ) userExtraFeatureNames;

          _validate = assert lib.assertMsg (systemOnlyFeatures == [])
            "User extra-features must have home modules. System-only features should be added to the host: ${lib.concatStringsSep ", " systemOnlyFeatures}";
            true;

          # Build the feature list for this user
          coreFeatureNames = self.lib.resolver.coreFeatures;
          hostFeatureNames = map (f: f.name) (
            if includeHostFeatures then allHostFeatures else
            lib.filter (f: lib.elem f.name coreFeatureNames) allHostFeatures
          );

          allFeatureNames = lib.unique (hostFeatureNames ++ userExtraFeatureNames);

          # Use the resolver for proper dependency resolution
          resolved = builtins.seq _validate (resolveFeatures {
            featuresConfig = config.features;
            hostFeatures = allFeatureNames;
            hostExclusions = userExclusions;
          });

          resolvedFeatures = builtins.attrValues resolved.features;
          userActiveProviders = builtins.attrValues (resolved.providers or {});

          homeModules = collectPlatformHomeModules {
            features = resolvedFeatures;
            activeProviders = userActiveProviders;
            inherit system dispatchableArgs;
            availableContext = fullContext // {
              user = augmentedUser;
              osConfig = true;
            };
          };

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

          # Use the new resolver to get both features and providers
          resolved = resolveFeatures {
            featuresConfig = config.features;
            hostFeatures = if usePrecomputed then hostOptions.features else overrideFeatures;
            hostExclusions = hostOptions.excluded-features or [ ];
          };

          activeFeatures = if usePrecomputed then hostOptions.features else lib.attrNames resolved.features;

          allHostFeatures = map (name: config.features.${name}) activeFeatures;
          activeProviders = builtins.attrValues (resolved.providers or { });

          systemModules = collectPlatformSystemModulesNew {
            features = allHostFeatures;
            inherit activeProviders dispatchableArgs;
            availableContext = fullContext;
            inherit (hostOptions) system;
          };

          # Resolve all users via ACL
          canonicalUsers = config.users or { };
          groupDefs = config.groups or { };
          users = resolveUsers lib' canonicalUsers environment hostOptions groupDefs;

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

          # Collect context contributions from active features
          featureContextFns = lib.foldl' (acc: f: acc // (f.contextProvides or { })) { } allHostFeatures;

          # Base context — always available
          baseContext = {
            inherit
              environment
              users
              settings
              inputs
              ;
            host = hostOptions // {
              users = {
                all = users;
                enabled = enabledUsers;
                enabledNames = builtins.attrNames enabledUsers;
              };
            };
            flakeLib = self.lib;
          };

          # Full context — lazy recursive attrset
          # Feature-contributed context values are functions that receive fullContext
          fullContext = baseContext // lib.mapAttrs (_name: fn: fn fullContext) featureContextFns;

          # Context registry for parametric dispatch
          contextRegistry = self.lib.modules.baseContextNames ++ lib.attrNames featureContextFns;
          dispatchableArgs = contextRegistry ++ self.lib.modules.stageDistinctArgs;

          specialArgs = fullContext // {
            inherit pkgs' inputs;
            lib = lib';
          };
          homeManagerUsersModule = {
            home-manager.users = lib'.mapAttrs (
              _username: resolvedUser:
              makeHomeConfig {
                inherit
                  resolvedUser
                  allHostFeatures
                  activeProviders
                  fullContext
                  dispatchableArgs
                  ;
                inherit (hostOptions) system;
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
            fullContext
            dispatchableArgs
            activeProviders
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
