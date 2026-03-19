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
      # SECTION 2: ACL-Based User Resolution
      # ============================================================================
      # groups (shared) + environment.access + host.allow-logins-by → resolved users

      # Helper: coalesce — first non-null value wins
      coalesce = a: b: if a != null then a else b;

      # Resolve transitive group membership for a set of direct groups
      # Returns: all group names the user is a member of (including transitive)
      resolveGroupMembership =
        groupDefs: directGroups:
        let
          # For each group, find all groups that include it as a member (reverse lookup)
          # i.e., if "users" has members = [ "admins" ], then being in "admins" means
          # you're transitively in "users"
          traverse =
            visited: toVisit:
            if toVisit == [ ] then
              visited
            else
              let
                current = lib.head toVisit;
                remaining = lib.tail toVisit;
              in
              if lib.elem current visited then
                traverse visited remaining
              else
                let
                  # Find all groups that list `current` in their members
                  parentGroups = lib.filterAttrs (_name: g: lib.elem current (g.members or [ ])) groupDefs;
                  parentNames = lib.attrNames parentGroups;
                in
                traverse (visited ++ [ current ]) (remaining ++ parentNames);
        in
        traverse [ ] directGroups;

      # Build resolved user from canonical user + ACL + env/host overrides
      resolveUser =
        {
          userName,
          canonicalUsers,
          environment,
          hostOptions,
          groupDefs,
        }:
        let
          cu = canonicalUsers.${userName} or null;
          envUser = environment.users.${userName} or { };
          hostUser = hostOptions.users.${userName} or { };

          # Identity from canonical user
          identity =
            if cu != null then
              {
                inherit (cu.identity)
                  displayName
                  email
                  sshKeys
                  gpgKey
                  ;
              }
            else
              {
                displayName = userName;
                email = null;
                sshKeys = [ ];
                gpgKey = null;
              };

          # System fields: canonical base → env overrides → host overrides
          sysBase =
            if cu != null then
              {
                inherit (cu.system)
                  uid
                  gid
                  linger
                  extra-features
                  excluded-features
                  include-host-features
                  ;
              }
            else
              {
                uid = null;
                gid = null;
                linger = false;
                extra-features = [ ];
                excluded-features = [ ];
                include-host-features = false;
              };

          sys = {
            inherit (sysBase) uid gid;
            linger = coalesce (envUser.linger or null) (coalesce (hostUser.linger or null) sysBase.linger);
            extra-features = coalesce (hostUser.extra-features or null) (
              coalesce (envUser.extra-features or null) sysBase.extra-features
            );
            excluded-features = coalesce (hostUser.excluded-features or null) (
              coalesce (envUser.excluded-features or null) sysBase.excluded-features
            );
            include-host-features = coalesce (hostUser.include-host-features or null) (
              coalesce (envUser.include-host-features or null) sysBase.include-host-features
            );
          };

          # ACL resolution
          directGroups = environment.access.${userName} or [ ];
          resolvedGroups = resolveGroupMembership groupDefs directGroups;

          # Scope filter — returns group names matching a given scope
          scopedGroups = scope: lib.filter (g: (groupDefs.${g}.scope or "") == scope) resolvedGroups;

          # Derive enable from system-scoped groups ∩ host.allow-logins-by
          enable = lib.any (g: lib.elem g (hostOptions.allow-logins-by or [ ])) (scopedGroups "system");
        in
        {
          inherit identity;
          system = sys // {
            inherit enable;
            systemGroups = scopedGroups "unix";
          };
          inherit directGroups resolvedGroups scopedGroups;
        };

      # Build all resolved users for a host context
      resolveUsers =
        lib': canonicalUsers: environment: hostOptions: groupDefs:
        let
          canonicalUserNames = builtins.attrNames canonicalUsers;
          environmentAccessNames = builtins.attrNames (environment.access or { });
          environmentUserNames = builtins.attrNames (environment.users or { });
          hostUserNames = builtins.attrNames (hostOptions.users or { });
          allUserNames = lib'.unique (
            canonicalUserNames ++ environmentAccessNames ++ environmentUserNames ++ hostUserNames
          );
        in
        lib'.genAttrs allUserNames (
          userName:
          resolveUser {
            inherit
              userName
              canonicalUsers
              environment
              hostOptions
              groupDefs
              ;
          }
        );

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
