# Host configuration builders: context assembly, NixOS/Darwin system creation.
{
  lib,
  self,
  config,
  inputs,
  withSystem,
  ...
}:
{
  flake.lib.hosts =
    let
      inherit (self.lib.features.collection) collectPlatformSystemModules;
      inherit (self.lib.users) resolveUsers;
      inherit (self.lib.features) resolveFeatureSettings;
      inherit (self.lib.features.resolver) resolveFeatures;
      inherit (self.lib.features) baseContextNames stageDistinctArgs;

      makeHomeConfig = config.flake.lib.hosts.makeHomeConfig;

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
            label = hostOptions.hostname;
          };

          activeFeatures = if usePrecomputed then hostOptions.features else lib.attrNames resolved.features;

          allHostFeatures = map (name: config.features.${name}) activeFeatures;
          activeProviders = builtins.attrValues (resolved.providers or { });

          systemModules = collectPlatformSystemModules {
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
          featureContextFns = lib.foldl' (acc: f: acc // f.contextProvides) { } allHostFeatures;

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
          contextRegistry = baseContextNames ++ lib.attrNames featureContextFns;
          dispatchableArgs = contextRegistry ++ stageDistinctArgs;

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
        prepareHostContext
        mkHost
        mkHostKexec
        mkNixosHost
        mkDarwinHost
        ;
    };
}
