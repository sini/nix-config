{ lib, ... }:
let
  inherit (lib) mkOption types;

  # ============================================================================
  # User Type Builders
  # ============================================================================
  # These define the shape of user options at each configuration level:
  # canonical (users/options.nix), environment, and host.

  # Structured SSH key type — each key carries an optional tag for filtering
  sshKeyType = types.submodule {
    options = {
      tag = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Tag to categorize the SSH key (e.g., 'laptop', 'workstation', 'yubikey')";
      };
      key = mkOption {
        type = types.str;
        description = "SSH public key string";
      };
    };
  };

  # Identity submodule type (shared between env users and canonical users)
  identitySubmoduleType =
    name:
    types.submodule {
      options = {
        displayName = mkOption {
          type = types.str;
          default = name;
          description = "Display name for the user (defaults to username)";
        };

        email = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Email address for the user";
        };

        sshKeys = mkOption {
          type = types.listOf sshKeyType;
          default = [ ];
          description = "SSH public keys for the user, each with an optional tag";
        };

        gpgKey = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "GPG key ID for the user (parent key ID)";
        };
      };
    };

  # Environment-level user option — nullable overrides only, plus derived identity
  mkEnvUsersOpt =
    {
      description,
      canonicalUsers ? { },
    }:
    mkOption {
      type = types.lazyAttrsOf (
        types.submodule (
          { name, ... }:
          {
            options = {
              # Derived identity — read-only, resolved from canonical users.<name>.identity
              identity = mkOption {
                type = identitySubmoduleType name;
                readOnly = true;
                default = if canonicalUsers ? ${name} then canonicalUsers.${name}.identity else { };
                description = "Identity information (derived from canonical users.<name>.identity)";
              };

              # Nullable overrides (null = inherit from users.<name>.system)
              linger = mkOption {
                type = types.nullOr types.bool;
                default = null;
                description = "Enable lingering override (null inherits from users.<name>.system)";
              };

              extra-features = mkOption {
                type = types.nullOr (types.listOf types.str);
                default = null;
                description = "Extra home-manager features override (null inherits from users.<name>.system)";
              };

              excluded-features = mkOption {
                type = types.nullOr (types.listOf types.str);
                default = null;
                description = "Excluded features override (null inherits from users.<name>.system)";
              };

              include-host-features = mkOption {
                type = types.nullOr types.bool;
                default = null;
                description = "Whether to inherit host features (null inherits from users.<name>.system)";
              };
            };
          }
        )
      );
      default = { };
      inherit description;
    };

  # Host-specific users option — all nullable for overriding env/canonical users
  mkHostUsersOpt =
    description:
    mkOption {
      type = types.lazyAttrsOf (
        types.submodule (_: {
          options = {
            # Nullable overrides
            linger = mkOption {
              type = types.nullOr types.bool;
              default = null;
              description = "Enable lingering override (null to inherit)";
            };

            extra-features = mkOption {
              type = types.nullOr (types.listOf types.str);
              default = null;
              description = "Extra home-manager features override (null to inherit)";
            };

            excluded-features = mkOption {
              type = types.nullOr (types.listOf types.str);
              default = null;
              description = "Excluded features override (null to inherit)";
            };

            include-host-features = mkOption {
              type = types.nullOr types.bool;
              default = null;
              description = "Whether to inherit host features (null to inherit)";
            };
          };
        })
      );
      default = { };
      inherit description;
    };

  # ============================================================================
  # ACL-Based User Resolution
  # ============================================================================
  # groups (shared) + environment.access + env/host system-access-groups → resolved users

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
              enableUnixAccount
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
            enableUnixAccount = false;
            uid = null;
            gid = null;
            linger = false;
            extra-features = [ ];
            excluded-features = [ ];
            include-host-features = false;
          };

      sys = {
        inherit (sysBase) enableUnixAccount uid gid;
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

      # Label filter — returns group names with a given label
      groupsByLabel = label: lib.filter (g: lib.elem label (groupDefs.${g}.labels or [ ])) resolvedGroups;

      # Derive enable from user-role groups ∩ merged system-access-groups (env + host)
      mergedAccessGroups = lib.unique (
        (environment.system-access-groups or [ ]) ++ (hostOptions.system-access-groups or [ ])
      );
      enable = lib.any (g: lib.elem g mergedAccessGroups) (groupsByLabel "user-role");
    in
    {
      inherit identity;
      system = sys // {
        inherit enable;
        systemGroups = groupsByLabel "posix";
      };
      inherit directGroups resolvedGroups groupsByLabel;
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
in
{
  flake.lib.users = {
    inherit
      sshKeyType
      identitySubmoduleType
      mkEnvUsersOpt
      mkHostUsersOpt
      coalesce
      resolveGroupMembership
      resolveUser
      resolveUsers
      ;
  };
}
