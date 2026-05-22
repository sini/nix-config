# User registry and access-driven user resolution policies.
#
# Users are resolved onto hosts via environment and host-level
# access group intersection. The fleet.user-access ACL mappings
# and user registry drive the resolution (following fleet-demo pattern).
{
  lib,
  den,
  config,
  ...
}:
let
  inherit (den.lib.policy) resolve;
  inherit (lib) mkOption types;

  registry = config.den.users.registry;
  accessByEnv = config.fleet.user-access.by-environment;
  accessByHost = config.fleet.user-access.by-host;

  # Filter registry users whose groups intersect the granted set.
  matchRegistryUsers =
    grantedGroups:
    lib.filter (
      name:
      let
        userGroups = registry.${name}.groups or [ ];
      in
      builtins.any (g: lib.elem g grantedGroups) userGroups
    ) (builtins.attrNames registry);

  # Submodule for group-based access grants.
  accessGrantType = types.submodule {
    options.groups = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Groups granted access";
    };
  };

  sshKeyType = types.submodule {
    options = {
      tag = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Tag to categorize the SSH key";
      };
      key = mkOption {
        type = types.str;
        description = "SSH public key string";
      };
    };
  };

  # Registry entry type — mirrors the standard user entity shape so that
  # pipeline self-provide, define-user, and other batteries find the
  # expected attributes (userName, aspect, classes).
  registryUserType = types.submodule (
    { name, config, ... }:
    {
      freeformType = types.attrsOf types.anything;
      imports = [ den.schema.user ];
      config._module.args.user = config;
      options = {
        name = mkOption {
          type = types.str;
          default = name;
          description = "User name (from attrset key)";
        };
        userName = mkOption {
          type = types.str;
          default = name;
          description = "User account name";
        };
        classes = mkOption {
          type = types.listOf types.str;
          default = [ "user" ];
          description = "Home management nix classes";
        };
        aspect = mkOption {
          type = types.raw;
          default = den.aspects.${name} or { };
          defaultText = "den.aspects.<name>";
          description = "Aspect that configures this user";
        };
        groups = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Group memberships for access policy selection";
        };
        identity = mkOption {
          type = types.submodule {
            options = {
              displayName = mkOption {
                type = types.str;
                default = "";
                description = "Display name for the user";
              };
              email = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Email address for the user";
              };
              gpgKey = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "GPG key ID for the user";
              };
              sshKeys = mkOption {
                type = types.listOf sshKeyType;
                default = [ ];
                description = "SSH public keys for the user";
              };
            };
          };
          default = { };
          description = "User identity information";
        };
      };
    }
  );
in
{
  # User registry option.
  options.den.users.registry = mkOption {
    type = types.attrsOf registryUserType;
    default = { };
    description = "User registry with extended schema for fleet policy resolution";
  };

  # Access mappings: under fleet (following fleet-demo pattern).
  options.fleet.user-access = {
    by-environment = mkOption {
      type = types.attrsOf accessGrantType;
      default = { };
      description = "Grant user groups access to all hosts in an environment";
    };
    by-host = mkOption {
      type = types.attrsOf accessGrantType;
      default = { };
      description = "Grant user groups access to a specific host";
    };
  };

  config = {
    # Promote users to real entities.
    den.schema.user.isEntity = true;
    den.schema.user.classes = lib.mkDefault [ "homeManager" ];

    # host -> users (by environment): resolve registry users whose groups
    # intersect the fleet.user-access.by-environment grant for that env.
    den.policies.env-users =
      { host, ... }:
      let
        grant = accessByEnv.${host.environment or "prod"} or { groups = [ ]; };
        matched = matchRegistryUsers grant.groups;
      in
      map (name: resolve.to "user" { user = registry.${name}; }) matched;

    # host -> users (by host): resolve registry users whose groups
    # intersect the fleet.user-access.by-host grant for that host.
    den.policies.host-users =
      { host, ... }:
      let
        grant = accessByHost.${host.name} or { groups = [ ]; };
        matched = matchRegistryUsers grant.groups;
      in
      map (name: resolve.to "user" { user = registry.${name}; }) matched;
  };
}
