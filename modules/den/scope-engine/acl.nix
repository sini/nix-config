# ACL scope graph: group membership + system-access gating.
#
# Three-level resolution (groups -> environments -> hosts), evaluated via
# gen-scope (HOAG). A user's POSIX/kanidm group membership is the transitive
# closure of their registry groups over the group-membership graph (M edges),
# partitioned by group scope.
#
# Evaluated attributes:
#   effectiveGates — merged env+host system-access-groups (union)
#   resolveUser    — paramAttr (hostId) (userName) → access record
#                    { enable, systemGroups, kanidmGroups, allGroups, ... }
{
  inputs,
  lib,
  config,
  den,
  ...
}:
let
  inherit (lib) mkOption types;

  engine = inputs.scope-engine { inherit lib; };

  flatHosts = lib.foldl' (acc: system: acc // (den.hosts.${system} or { })) { } (
    builtins.attrNames (den.hosts or { })
  );

  groups = config.den.groups or { };
  environments = config.den.environments or { };
  registry = config.den.users.registry or { };
  hosts = flatHosts;

  groupNames = builtins.attrNames groups;
  envNames = builtins.attrNames environments;
  hostNames = builtins.attrNames hosts;

  # Group scope is derived from den.groups labels: posix groups land in the
  # "system" scope (→ NixOS extraGroups), oauth-grant groups in "kanidm".
  scopeOf =
    gname:
    let
      labels = groups.${gname}.labels or [ ];
    in
    if builtins.elem "posix" labels then
      "system"
    else if builtins.elem "oauth-grant" labels then
      "kanidm"
    else
      "system";

  roots = engine.buildNodes {
    # Parent edges: hosts → environments → root.
    parentGraph = engine.overlays (
      [ (engine.star "root" (map (e: "env:${e}") envNames)) ]
      ++ map (host: engine.edge "host:${host}" "env:${hosts.${host}.environment or "prod"}") hostNames
    );

    # M edges: group-to-group membership. An edge FROM member TO group means
    # the member inherits the group's privileges (members = [...] on the group).
    edgeGraphs.M = engine.overlays (
      (lib.concatMap (
        gname: map (member: engine.edge "group:${member}" "group:${gname}") (groups.${gname}.members or [ ])
      ) groupNames)
      # Ensure every group exists as a vertex even with no membership edges.
      ++ [ (engine.vertices (map (g: "group:${g}") groupNames)) ]
    );

    decls = lib.listToAttrs (
      [
        {
          name = "root";
          value = { };
        }
      ]
      ++ map (gname: {
        name = "group:${gname}";
        value = {
          scope = scopeOf gname;
          description = groups.${gname}.description or "";
          name = gname;
        };
      }) groupNames
      ++ map (ename: {
        name = "env:${ename}";
        value = {
          name = ename;
          system-access-groups = environments.${ename}.system-access-groups or [ ];
        };
      }) envNames
      ++ map (hname: {
        name = "host:${hname}";
        value = {
          name = hname;
          system-access-groups = hosts.${hname}.system-access-groups or [ ];
        };
      }) hostNames
    );

    types = lib.listToAttrs (
      [
        {
          name = "root";
          value = "root";
        }
      ]
      ++ map (g: {
        name = "group:${g}";
        value = "group";
      }) groupNames
      ++ map (e: {
        name = "env:${e}";
        value = "environment";
      }) envNames
      ++ map (h: {
        name = "host:${h}";
        value = "host";
      }) hostNames
    );
  };

  # Transitive group closure over M edges: if you're in X, you're in everything
  # X is a member of.
  transitiveGroups =
    self: groupId:
    let
      direct = engine.followEdge "M" self groupId;
      transitive = lib.concatMap (gid: transitiveGroups self gid) direct;
    in
    lib.unique ([ groupId ] ++ direct ++ transitive);

  attributes = {
    # Structural attributes required by the evaluator / followEdge.
    children = _self: id: lib.filterAttrs (_: n: n.parent == id) roots;
    imports = _self: _id: [ ];
    "edges-M" = _self: id: (_self.node id).decls.__edges.M or [ ];

    # Merged login gates for a host: unique(env ++ host system-access-groups).
    effectiveGates =
      self: id:
      let
        node = self.node id;
        hostGates = node.decls.system-access-groups or [ ];
        envGates =
          if node.parent != null then (self.node node.parent).decls.system-access-groups or [ ] else [ ];
      in
      lib.unique (envGates ++ hostGates);

    # Resolve a user's full access on a host. Group membership is sourced from
    # the user registry (den-v2 single source of truth), expanded transitively
    # through the membership graph, and partitioned by group scope.
    resolveUser = engine.paramAttr (
      self: hostId: userName:
      let
        directGroups = registry.${userName}.groups or [ ];

        allGroupIds = lib.unique (
          lib.concatMap (gname: transitiveGroups self "group:${gname}") directGroups
        );
        allGroupNames = map (gid: (self.node gid).decls.name) (
          builtins.filter (gid: roots ? ${gid}) allGroupIds
        );

        byScope = scope: builtins.filter (gid: ((self.node gid).decls.scope or "") == scope) allGroupIds;
        namesForScope = scope: map (gid: (self.node gid).decls.name) (byScope scope);

        systemGroups = namesForScope "system";
        kanidmGroups = namesForScope "kanidm";

        gates = self.get hostId "effectiveGates";
        gateGroupIds = map (g: "group:${g}") gates;
        gateIntersection = builtins.filter (gid: builtins.elem gid gateGroupIds) (byScope "system");
        enable = gateIntersection != [ ];
      in
      {
        inherit userName enable directGroups;
        allGroups = builtins.sort builtins.lessThan allGroupNames;
        inherit systemGroups kanidmGroups;
        effectiveGates = gates;
      }
    );
  };
in
{
  options.fleet.acl = mkOption {
    type = types.raw;
    description = "Evaluated ACL scope graph from gen-scope";
    readOnly = true;
  };

  config.fleet.acl = engine.eval { inherit roots attributes; };
}
