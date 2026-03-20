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

      # ============================================================================
      # SECTION 1: Home Manager User Configuration
      # ============================================================================

      makeHomeConfig =
        {
          resolvedUser,
          allHostFeatures,
          ...
        }:
        let
          includeHostFeatures = resolvedUser.system.include-host-features or false;
          userExtraFeatures = resolvedUser.system.extra-features or [ ];
          userExclusions = resolvedUser.system.excluded-features or [ ];

          coreRoleFeatureNames = config.roles.core.features;
          isCore = f: lib.elem f.name coreRoleFeatureNames;

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
        in
        {
          imports = homeModules;
        };

      # ============================================================================
      # SECTION 3: Host Configuration Builders
      # ============================================================================

      prepareHostContext =
        {
          hostOptions,
          overrideRoles ? null,
        }:
        _system:
        let
          channel = config.channels.${hostOptions.channel};
          pkgs' = channel.nixpkgs;
          lib' = pkgs'.lib;
          home-manager' = channel.home-manager;
          nix-darwin' = channel.nix-darwin;

          environment = config.environments.${hostOptions.environment};

          usePrecomputed = overrideRoles == null;

          activeFeatures =
            if usePrecomputed then
              hostOptions.features
            else
              self.lib.modules.computeActiveFeatures {
                featuresConfig = config.features;
                rolesConfig = config.roles;
                hostRoles = overrideRoles;
                hostFeatures = hostOptions.extra-features or [ ];
                hostExclusions = hostOptions.excluded-features or [ ];
              };

          allHostFeatures = map (name: config.features.${name}) activeFeatures;

          systemModules = collectPlatformSystemModules allHostFeatures hostOptions.system;

          # Resolve all users via ACL
          canonicalUsers = config.users or { };
          groupDefs = config.groups or { };
          users = resolveUsers lib' canonicalUsers environment hostOptions groupDefs;

          specialArgs = {
            inherit
              pkgs'
              inputs
              environment
              users
              ;
            host = hostOptions;
            lib = lib';
          };

          enabledUsers = lib'.filterAttrs (_: u: u.system.enable or false) users;
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
