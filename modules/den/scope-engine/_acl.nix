# ACL scope graph: group membership + system-access gating.
#
# Builds a three-level resolution graph:
#   groups (M edges for transitive membership)
#     → environments (access bindings, system-access-groups)
#       → hosts (host-specific system-access-groups)
#
# Evaluated attributes:
#   effectiveGates — merged env+host system-access-groups (union)
#   resolveUser    — paramAttr (hostId, userName) → access record
{ engine, lib }:
let
  # Build the ACL graph from registry data.
  # Arguments:
  #   groups       ��� attrset of group definitions (from den.groups)
  #   environments — attrset of environment configs (from den.environments)
  #   hosts        — attrset of host configs (from den.hosts, flattened across systems)
  build =
    {
      groups ? { },
      environments ? { },
      hosts ? { },
    }:
    let
      groupNames = builtins.attrNames groups;
      envNames = builtins.attrNames environments;
      hostNames = builtins.attrNames hosts;

      # Transitive group resolution helper (used in attributes).
      transitiveGroups =
        self: groupId:
        let
          direct = engine.followEdge "M" self groupId;
          transitive = lib.concatMap (gid: transitiveGroups self gid) direct;
        in
        lib.unique ([ groupId ] ++ direct ++ transitive);

      baseNodes = engine.buildNodes {
        # Parent edges: hosts → environments → root.
        parentGraph = engine.overlays (
          [ (engine.star "root" (map (e: "env:${e}") envNames)) ]
          ++ map (
            host:
            engine.edge "host:${host}" "env:${hosts.${host}.environment or "prod"}"
          ) hostNames
        );

        # M edges: group-to-group membership (transitive).
        edgeGraphs = {
          M = engine.overlays (
            (lib.concatMap (
              gname:
              let
                g = groups.${gname};
                members = g.members or [ ];
              in
              map (member: engine.edge "group:${member}" "group:${gname}") members
            ) groupNames)
            ++ [ (engine.vertices (map (g: "group:${g}") groupNames)) ]
          );
        };

        decls = lib.listToAttrs (
          [ { name = "root"; value = { }; } ]
          ++ map (gname: {
            name = "group:${gname}";
            value = {
              scope =
                let
                  labels = groups.${gname}.labels or [ ];
                in
                if builtins.elem "posix" labels then
                  "system"
                else if builtins.elem "oauth-grant" labels then
                  "kanidm"
                else
                  "system";
              description = groups.${gname}.description or "";
              name = gname;
            };
          }) groupNames
          ++ map (ename: {
            name = "env:${ename}";
            value = {
              name = ename;
              system-access-groups = environments.${ename}.system-access-groups or [ ];
              access = environments.${ename}.access or { };
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
          [ { name = "root"; value = "root"; } ]
          ++ map (g: { name = "group:${g}"; value = "group"; }) groupNames
          ++ map (e: { name = "env:${e}"; value = "environment"; }) envNames
          ++ map (h: { name = "host:${h}"; value = "host"; }) hostNames
        );
      };

      attributes = {
        # Merged system-access-groups: union of env + host gates.
        effectiveGates =
          self: id:
          let
            node = self.nodes.${id};
            hostGates = node.decls.system-access-groups or [ ];
            envGates =
              if node.parent != null then
                self.nodes.${node.parent}.decls.system-access-groups or [ ]
              else
                [ ];
          in
          lib.unique (envGates ++ hostGates);

        # Resolve a user's full access on a given host.
        # Usage: result.evaluated."host:foo".get "resolveUser" "username"
        resolveUser = engine.paramAttr (
          self: hostId: userName:
          let
            hostNode = self.nodes.${hostId};
            envId = hostNode.parent;
            envAccess = self.nodes.${envId}.decls.access or { };
            directGroups = envAccess.${userName} or [ ];

            allGroupIds = lib.unique (
              lib.concatMap (gname: transitiveGroups self "group:${gname}") directGroups
            );
            allGroupNames = map (gid: self.nodes.${gid}.decls.name)
              (builtins.filter (gid: self.nodes ? ${gid}) allGroupIds);

            byScope = scope:
              builtins.filter (gid: (self.nodes.${gid}.decls.scope or "") == scope) allGroupIds;
            namesForScope = scope: map (gid: self.nodes.${gid}.decls.name) (byScope scope);

            systemGroups = namesForScope "system";
            kanidmGroups = namesForScope "kanidm";

            gates = self.evaluated.${hostId}.get "effectiveGates";
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
    engine.eval {
      inherit baseNodes attributes;
    };
in
{
  inherit build;
}
