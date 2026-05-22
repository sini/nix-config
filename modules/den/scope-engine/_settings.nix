# Settings cascade scope graph.
#
# Builds a config-cascade graph for settings resolution:
#   root → environment → host → user
#
# Import edges model delegation (env delegates settings to another env).
#
# Evaluated attributes:
#   resolvedSettings — full resolved settings for a node (local > import > parent)
#   setting          — paramAttr for per-key demand-driven lookup
#   settingSources   — provenance per key (local/import/inherited)
#   overriddenKeys   — keys that shadow a parent value
{ engine, lib }:
let
  # Build the settings cascade graph.
  build =
    {
      environments ? { },
      hosts ? { },
      users ? { },
    }:
    let
      envNames = builtins.attrNames environments;
      hostNames = builtins.attrNames hosts;
      userNames = builtins.attrNames users;

      parentEdges = engine.overlays (
        [ (engine.star "root" (map (e: "env:${e}") envNames)) ]
        ++ map (
          host:
          engine.edge "host:${host}" "env:${hosts.${host}.environment or "prod"}"
        ) hostNames
        ++ map (
          user:
          let
            userCfg = users.${user};
            parentId =
              if userCfg ? host && userCfg.host != null then
                "host:${userCfg.host}"
              else
                "root";
          in
          engine.edge "user:${user}" parentId
        ) userNames
      );

      importEdges = engine.overlays (
        lib.concatMap (
          ename:
          let
            env = environments.${ename};
            delegation = env.delegation or { };
            targets = lib.filter (t: t != null) [
              (delegation.metricsTo or null)
              (delegation.authTo or null)
              (delegation.logsTo or null)
            ];
          in
          map (target: engine.edge "env:${ename}" "env:${target}") targets
        ) envNames
      );

      baseNodes = engine.buildNodes {
        parentGraph = parentEdges;
        importGraph = importEdges;

        decls = lib.listToAttrs (
          [ { name = "root"; value = { }; } ]
          ++ map (ename: {
            name = "env:${ename}";
            value = environments.${ename}.tags or { };
          }) envNames
          ++ map (hname: {
            name = "host:${hname}";
            value = hosts.${hname}.settings or { };
          }) hostNames
          ++ map (uname: {
            name = "user:${uname}";
            value = users.${uname}.system.settings or (users.${uname}.settings or { });
          }) userNames
        );

        types = lib.listToAttrs (
          [ { name = "root"; value = "root"; } ]
          ++ map (e: { name = "env:${e}"; value = "environment"; }) envNames
          ++ map (h: { name = "host:${h}"; value = "host"; }) hostNames
          ++ map (u: { name = "user:${u}"; value = "user"; }) userNames
        );
      };

      attributes = {
        setting = engine.paramAttr (
          self: id: key:
          engine.query { dataFilter = node: node.decls.${key} or null; } self id
        );

        resolvedSettings =
          self: id:
          let
            node = self.nodes.${id};
            local = node.decls;
            importedSettings = lib.foldl' (
              acc: iid:
              engine.shadow (self.evaluated.${iid}.get "resolvedSettings") acc
            ) { } node.imports;
            parentSettings =
              if node.parent != null then
                self.evaluated.${node.parent}.get "resolvedSettings"
              else
                { };
          in
          engine.shadow local (engine.shadow importedSettings parentSettings);

        overriddenKeys =
          self: id:
          let
            allResults = key: engine.queryAll { dataFilter = node: node.decls.${key} or null; } self id;
            localKeys = builtins.attrNames self.nodes.${id}.decls;
          in
          builtins.filter (key: builtins.length (allResults key) > 1) localKeys;

        settingSources =
          self: id:
          let
            resolved = self.evaluated.${id}.get "resolvedSettings";
          in
          lib.mapAttrs (
            key: _:
            let
              node = self.nodes.${id};
              isLocal = node.decls ? ${key};
              isImported = builtins.any (
                iid: (self.evaluated.${iid}.get "resolvedSettings") ? ${key}
              ) node.imports;
            in
            if isLocal then
              "local"
            else if isImported then
              "import"
            else
              "inherited"
          ) resolved;
      };
    in
    engine.eval {
      inherit baseNodes attributes;
    };
in
{
  inherit build;
}
