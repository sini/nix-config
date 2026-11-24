# User facts and access-driven user assignment.
#
# Users live in den's registry (den.users). Which users a host gets is decided
# by den's assignment stage, before any host is resolved, so the rule reads only
# facts: the host's environment and system-access-groups, each user's groups.
# The environments' gates and fleet.user-access grants are fleet data, read
# from config.
{
  lib,
  den,
  config,
  ...
}:
let
  inherit (lib) mkOption types;

  groupNames = mkOption {
    type = types.listOf types.str;
    default = [ ];
  };

  # Submodule for group-based access grants.
  accessGrantType = types.submodule {
    options.groups = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Groups granted access";
    };
  };

  # The groups that admit a user on a host: grants (environment + host + the
  # host's own gates, which are also an implicit grant) filtered to the gates
  # (environment + host); with no gate at all, every grant admits.
  accessGroupsFor =
    host:
    let
      inherit (config) fleet;
      env = host.facts.environment;
      envGrant = (fleet.user-access.by-environment.${env} or { groups = [ ]; }).groups;
      envGate = config.den.environments.${env}.system-access-groups or [ ];
      hostGrant = (fleet.user-access.by-host.${host.name} or { groups = [ ]; }).groups;
      hostGate = host.facts.system-access-groups;
      effectiveGate = lib.unique (envGate ++ hostGate);
      allGrants = lib.unique (envGrant ++ hostGrant ++ hostGate);
    in
    if effectiveGate == [ ] then
      allGrants
    else
      builtins.filter (g: builtins.elem g effectiveGate) allGrants;
in
{
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

    # What assignment reads. A user's groups are their DIRECT memberships; the
    # nested closure over den.groups is applied by its readers (acl, kanidm, media).
    den.schema.user.facts = [
      {
        options.groups = groupNames // {
          description = "Group memberships (direct)";
        };
      }
    ];
    den.schema.host.facts = [
      {
        options.environment = mkOption {
          type = types.str;
          default = "prod";
          description = "Environment name that this host belongs to";
        };
        options.system-access-groups = groupNames // {
          description = "Groups granting Unix account creation on this host";
        };
      }
    ];

    # Users whose direct groups meet the host's access groups.
    den.policies.fleet-access = den.lib.policy.assign (
      { host, users }:
      let
        access = accessGroupsFor host;
      in
      builtins.attrNames (
        lib.filterAttrs (_: u: builtins.any (g: builtins.elem g access) u.facts.groups) users
      )
    );
  };
}
