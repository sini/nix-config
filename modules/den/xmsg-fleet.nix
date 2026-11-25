# Fleet topology value (xmsg.lib.fleet.type) derived from den.hosts,
# den.users.registry, services, and den.clusters.
{
  den,
  inputs,
  lib,
  self,
  ...
}:
let
  xl = import ./aspects/applications/dev/ai/mcp/_xmsg-lib.nix { inherit lib self; };

  allHosts =
    (builtins.attrValues (den.hosts.x86_64-linux or { }))
    ++ (builtins.attrValues (den.hosts.aarch64-darwin or { }));

  # Every host with xmsg federation enabled sits in the json64.dev domain.
  trustDomain = "json64.dev";
  rootCa = xl.caCrt (xl.caDir + "/root.crt");

  fedOf = h: h.settings.applications.dev.ai.mcp.xmsg.federation or { };
  mxOf = h: h.settings.services.matrix-xmsg or { rooms = [ ]; };

  hostByName = builtins.listToAttrs (
    map (h: {
      name = h.name;
      value = h;
    }) allHosts
  );

  # User nodes: one per (user, host) in federation.nodes.
  userNodeEntries = lib.concatMap (
    h:
    let
      fed = fedOf h;
    in
    lib.mapAttrsToList (
      u: nCfg:
      let
        port = nCfg.port or 7788;
      in
      {
        name = xl.nodeName h.name u;
        user = u;
        host = h;
        value = {
          kind = "node";
          address = "${h.name}.ts.${trustDomain}:${toString port}";
          addresses.lan = "${builtins.head h.ipv4}:${toString port}";
          listenPort = port;
          identity = xl.spiffeOf trustDomain h.name u;
          acceptRelayed = fed.relayedBy or [ ];
        };
      }
    ) (fed.nodes or { })
  ) allHosts;

  userNodesByUser = lib.groupBy (e: e.user) userNodeEntries;

  # Collector nodes: one per enabled federation.collector.
  collectorEntries = lib.concatMap (
    h:
    let
      col = (fedOf h).collector or { enable = false; };
      colUser = col.user or "sini";
    in
    lib.optional (col.enable or false) {
      name = "${colUser}.collector";
      value = {
        kind = "collector";
        identity = xl.spiffeOf trustDomain "collector" colUser;
      };
    }
  ) allHosts;

  # Service nodes: matrix-xmsg on hosts with rooms != [].
  serviceNodeEntries = lib.concatMap (
    h:
    let
      mx = mxOf h;
      port = mx.xmsgPort or 7791;
    in
    lib.optional ((mx.rooms or [ ]) != [ ]) {
      name = xl.nodeName h.name "matrix-xmsg";
      owner = h.system-owner;
      host = h;
      guardsGuard =
        (mx.screenMentions or false)
        || (mx.screenSolicited or false)
        || lib.any (r: r.screenMentions or false == true) (lib.attrValues (mx.roomRoutes or { }));
      value = {
        kind = "node";
        address = "${h.name}.ts.${trustDomain}:${toString port}";
        addresses.lan = "${builtins.head h.ipv4}:${toString port}";
        listenPort = port;
        identity = xl.spiffeOf trustDomain h.name "matrix-xmsg";
      };
    }
  ) allHosts;

  # Cluster leaves: xmsg-gateway and genie-guard.
  allClusters = builtins.attrValues (den.clusters or { });

  ownerNodeOf = hn: "${hostByName.${hn}.system-owner}.${hn}";

  gatewayLeaves = lib.concatMap (
    cl:
    let
      gw = cl.settings.kubernetes.services.ai.xmsg-gateway or { enable = false; };
      hubs = map ownerNodeOf ([ gw.hub ] ++ (gw.extraHubs or [ ]));
      primaryHub = ownerNodeOf gw.hub;
      relayed = gw.relayed or [ ];
    in
    lib.optional (gw.enable or false) {
      name = "xmsg-gateway.xmsg-gateway";
      inherit hubs primaryHub relayed;
      allow = [
        "send"
        "reply"
        "list"
      ];
      targets = null;
      node = {
        kind = "leaf";
        network = "lan";
        ca = "/etc/xmsg/tls/ca.crt";
      };
    }
  ) allClusters;

  guardLeaves = lib.concatMap (
    cl:
    let
      gg = cl.settings.kubernetes.services.ai.genie-guard or { enable = false; };
      hubs = map ownerNodeOf ([ gg.hub ] ++ (gg.devHubs or [ ]));
    in
    lib.optional (gg.enable or false) {
      name = "genie-guard.genie";
      inherit hubs;
      primaryHub = ownerNodeOf gg.hub;
      relayed = [ ];
      allow = [ "reply" ];
      targets = [ "genie-guard" ];
      node = {
        kind = "leaf";
        network = "lan";
        ca = "/etc/xmsg/tls/ca.crt";
      };
    }
  ) allClusters;

  allLeaves = gatewayLeaves ++ guardLeaves;

  nodes = builtins.listToAttrs (
    (map (e: {
      inherit (e) name value;
    }) userNodeEntries)
    ++ collectorEntries
    ++ (map (e: {
      inherit (e) name value;
    }) serviceNodeEntries)
    ++ (map (l: {
      inherit (l) name;
      value = l.node;
    }) allLeaves)
  );

  # Meshes: one per user with >= 2 nodes, plus one per trusted user pair.
  sameUserMeshes = lib.concatLists (
    lib.mapAttrsToList (
      _: entries:
      lib.optional (builtins.length entries >= 2) {
        members = map (e: e.name) entries;
        allow = [
          "send"
          "reply"
          "list"
        ];
      }
    ) userNodesByUser
  );

  usersWithNodes = lib.sort builtins.lessThan (builtins.attrNames userNodesByUser);
  trustedPairMeshes = lib.concatMap (
    a:
    lib.concatMap (
      b:
      lib.optional (a < b && xl.trusts den.users.registry a b) {
        members = map (e: e.name) (userNodesByUser.${a} ++ userNodesByUser.${b});
        allow = [
          "send"
          "reply"
          "list"
        ];
      }
    ) usersWithNodes
  ) usersWithNodes;

  meshes = sameUserMeshes ++ trustedPairMeshes;

  # Explicit grants:
  # 1. Collector observe grants (per-user filter: c == "${u}.collector").
  # 2. Service node two-way grants with owner's nodes (allow = ["send" "reply"]).
  # 3. Leaf two-way grants with each hub (mailbox = true on hub -> leaf).
  collectorGrants = lib.concatMap (
    e:
    let
      obs = (fedOf e.host).observedBy or [ ];
      ownCols = lib.filter (c: c == "${e.user}.collector") obs;
    in
    map (c: {
      granter = e.name;
      grantee = c;
      grant = {
        allow = [ "observe" ];
      };
    }) ownCols
  ) userNodeEntries;

  serviceGrants = lib.concatMap (
    svc:
    let
      ownerNodes = userNodesByUser.${svc.owner} or [ ];
    in
    lib.concatMap (o: [
      {
        granter = o.name;
        grantee = svc.name;
        grant = {
          allow = [
            "send"
            "reply"
          ];
        };
      }
      {
        granter = svc.name;
        grantee = o.name;
        grant = {
          allow = [
            "send"
            "reply"
            "list"
          ];
        };
      }
    ]) ownerNodes
  ) serviceNodeEntries;

  leafGrants = lib.concatMap (
    l:
    lib.concatMap (h: [
      {
        granter = h;
        grantee = l.name;
        grant = {
          mailbox = true;
          inherit (l) allow targets;
        };
      }
      {
        granter = l.name;
        grantee = h;
        grant = {
          inherit (l) allow;
        };
      }
    ]) l.hubs
  ) allLeaves;

  serviceGuardGrants = lib.concatMap (
    svc:
    lib.optionals (svc.guardsGuard && builtins.any (l: l.name == "genie-guard.genie") allLeaves) [
      {
        granter = svc.name;
        grantee = "genie-guard.genie";
        grant = {
          mailbox = true;
          allow = [ "reply" ];
          targets = [ "genie-guard" ];
        };
      }
      {
        granter = "genie-guard.genie";
        grantee = svc.name;
        grant = {
          allow = [ "reply" ];
        };
      }
    ]
  ) serviceNodeEntries;

  allGrantPairs = collectorGrants ++ serviceGrants ++ leafGrants ++ serviceGuardGrants;
  grants = lib.foldl' (
    acc: g:
    acc
    // {
      ${g.granter} = (acc.${g.granter} or { }) // {
        ${g.grantee} = g.grant;
      };
    }
  ) { } allGrantPairs;

  relays = builtins.listToAttrs (
    lib.concatMap (
      l:
      lib.optional (l.relayed != [ ]) {
        name = l.name;
        value = {
          via = l.primaryHub;
          to = l.relayed;
        };
      }
    ) allLeaves
  );
in
{
  options.xmsg.fleet = lib.mkOption {
    type = inputs.xmsg.lib.fleet.type;
    description = "Fleet topology value derived from den.hosts, den.users.registry, services, and den.clusters.";
  };

  config.xmsg.fleet = {
    inherit
      trustDomain
      nodes
      meshes
      grants
      relays
      ;
    ca = rootCa;
  };
}
