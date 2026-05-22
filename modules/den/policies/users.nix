# User registry and access-driven user resolution policies.
#
# Users are resolved onto hosts via environment and host-level
# access group intersection. The legacy users registry and
# environment access mappings drive the resolution.
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

  # Resolve environment-level access: users whose groups intersect
  # the environment's system-access-groups.
  envAccessGroups =
    envName:
    let
      env = config.environments.${envName} or { };
    in
    env.system-access-groups or [ ];

  # Resolve per-host access: users granted access via host-level
  # system-access-groups.
  hostAccessGroups = hostCfg: hostCfg.system-access-groups or [ ];

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

  config = {
    # Promote users to real entities.
    den.schema.user.isEntity = true;
    den.schema.user.classes = lib.mkDefault [ "homeManager" ];

    # host -> users (by environment): resolve registry users whose groups
    # intersect the environment's system-access-groups.
    den.policies.env-users =
      { host, ... }:
      let
        granted = envAccessGroups (host.environment or "prod");
        matched = matchRegistryUsers granted;
      in
      map (name: resolve.to "user" { user = registry.${name}; }) matched;

    # host -> users (by host): resolve registry users whose groups
    # intersect the host's system-access-groups.
    den.policies.host-users =
      { host, ... }:
      let
        granted = hostAccessGroups host;
        matched = matchRegistryUsers granted;
      in
      map (name: resolve.to "user" { user = registry.${name}; }) matched;
  };
}
