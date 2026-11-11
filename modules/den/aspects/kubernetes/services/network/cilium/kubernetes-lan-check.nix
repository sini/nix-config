# The LAN pool's pure check (docs/dns-resolver.md §2.7), over axon's rendered
# Services and Cilium resources and the fleet's host data. Each property has a
# control that must fail it:
#   l2       the L2 policy selects exactly the Services holding a LAN-pool address
#            (blocky-lan), on enp2s0 alone. Control: the selector emptied
#   pool     the LAN pool draws for exactly those Services too. Control: the same
#   bgp      the BGP advertisement selects blocky and no Service holding a LAN-pool
#            address. Control: the L2 label's expression dropped
#   dhcp     every pool address lies in prod's LAN and below Default's DHCP range.
#            Control: 10.10.0.32/28, which reaches .46
#   topology cilium-config enables service topology, which blocky-lan's
#            PreferSameNode needs. Control: the key set "false"
#   statics  no host interface address, gateway or other cluster assignment lies
#            in the pool, and every LAN assignment does. Control: uplink's /29
#   nix build .#checks.x86_64-linux.kubernetes-lan
{ config, lib, ... }:
let
  axon = config.den.clusters.axon;
  lan = axon.networks.kubernetes-lan-loadbalancers;
  prodLan = config.den.environments.prod.networks.default;
  # UniFi Default's live dhcpd_start (read 2026-11-11). The range is not managed here.
  dhcpStart = "10.10.0.46";
  l2Label = import ./_l2.nix;

  # nixidy's typed resources carry every unset field as null.
  clean =
    v:
    if lib.isAttrs v then
      lib.mapAttrs (_: clean) (lib.filterAttrs (n: x: x != null && n != "_priority") v)
    else if lib.isList v then
      map clean v
    else
      v;
  apps = config.flake.nixidyEnvs.x86_64-linux.axon.config.applications;
  # Each object tagged with its application, the namespace a helm render may leave unset.
  objects = lib.concatLists (
    lib.mapAttrsToList (n: a: map (o: o // { app = n; }) (clean a.objects)) apps
  );
  ofKind = kind: lib.filter (o: o.kind == kind) objects;
  one =
    kind: name:
    lib.findFirst (o: o.metadata.name == name) (throw "kubernetes-lan: no ${kind}/${name}") (
      ofKind kind
    );
  lbServices = lib.filter (s: (s.spec.type or "") == "LoadBalancer") (ofKind "Service");
  id = s: "${s.metadata.namespace or s.app}/${s.metadata.name}";

  # Label selectors: matchLabels and Exists/DoesNotExist, the forms rendered here.
  selects =
    sel: s:
    let
      labels = s.metadata.labels or { };
      expr =
        e:
        if e.operator == "DoesNotExist" then
          !(labels ? ${e.key})
        else if e.operator == "Exists" then
          labels ? ${e.key}
        else
          throw "kubernetes-lan: selector operator ${e.operator}";
    in
    lib.all (k: (labels.${k} or null) == sel.matchLabels.${k}) (lib.attrNames (sel.matchLabels or { }))
    && lib.all expr (sel.matchExpressions or [ ]);
  selected = sel: lib.sort lib.lessThan (map id (lib.filter (selects sel) lbServices));

  ipToInt = ip: lib.foldl' (acc: o: acc * 256 + lib.toInt o) 0 (lib.splitString "." ip);
  range =
    cidr:
    let
      parts = lib.splitString "/" cidr;
      size = lib.foldl' (acc: _: acc * 2) 1 (lib.range 1 (32 - lib.toInt (lib.last parts)));
      base = ipToInt (lib.head parts) / size * size;
    in
    {
      first = base;
      last = base + size - 1;
    };
  inRange = r: ip: ipToInt ip >= r.first && ipToInt ip <= r.last;
  addrOf = s: s.metadata.annotations."lbipam.cilium.io/ips" or "";
  onLan = cidr: s: addrOf s != "" && inRange (range cidr) (addrOf s);
  lanServices = cidr: lib.sort lib.lessThan (map id (lib.filter (onLan cidr) lbServices));

  l2 = (one "CiliumL2AnnouncementPolicy" "lan").spec;
  ciliumConfig = (one "ConfigMap" "cilium-config").data;
  topologyOk = data: (data.enable-service-topology or null) == "true";
  pool = (one "CiliumLoadBalancerIPPool" "lan-pool").spec;
  bgp = lib.head (one "CiliumBGPAdvertisement" "loadbalancer-ips").spec.advertisements;

  l2Ok = sel: selected sel == lanServices lan.cidr && selected sel != [ ];
  bgpOk =
    sel:
    lib.elem "blocky/blocky" (selected sel)
    && lib.all (s: !(lib.elem s (lanServices lan.cidr))) (selected sel);

  dhcpOk =
    cidr:
    let
      r = range cidr;
    in
    r.first >= (range prodLan.cidr).first
    && r.last <= (range prodLan.cidr).last
    && r.last < ipToInt dhcpStart;

  hostAddrs = lib.concatMap (
    h:
    lib.concatMap (i: map (a: lib.head (lib.splitString "/" a)) (i.ipv4 or [ ])) (
      lib.attrValues (h.networking.interfaces or { })
    )
  ) (lib.concatMap lib.attrValues (lib.attrValues config.den.hosts));
  gateways = lib.concatMap (
    e: lib.filter (x: x != null) (map (n: n.gatewayIp or null) (lib.attrValues e.networks))
  ) (lib.attrValues config.den.environments);
  otherAssignments = lib.concatMap (
    c:
    lib.concatMap (n: lib.attrValues n.assignments) (
      lib.attrValues (removeAttrs c.networks [ "kubernetes-lan-loadbalancers" ])
    )
  ) (lib.attrValues config.den.clusters);
  staticsOk =
    cidr:
    lib.all (ip: !(inRange (range cidr) ip)) (hostAddrs ++ gateways ++ otherAssignments)
    && lib.all (inRange (range cidr)) (lib.attrValues lan.assignments);

  checks = {
    l2 = l2Ok l2.serviceSelector && l2.interfaces == [ "^enp2s0$" ] && l2.loadBalancerIPs;
    l2AllFails = !(l2Ok { });
    pool = l2Ok pool.serviceSelector && pool.blocks == [ { inherit (lan) cidr; } ];
    bgp = bgpOk bgp.selector;
    bgpNoL2ExprFails =
      !(bgpOk (
        bgp.selector
        // {
          matchExpressions = lib.filter (e: !(l2Label ? ${e.key})) bgp.selector.matchExpressions;
        }
      ));
    topology = topologyOk ciliumConfig;
    topologyOffFails = !(topologyOk (ciliumConfig // { enable-service-topology = "false"; }));
    blockyLanOnPool = lanServices lan.cidr == [ "blocky/blocky-lan" ];
    dhcp = dhcpOk lan.cidr;
    dhcpWideFails = !(dhcpOk "10.10.0.32/28");
    statics = staticsOk lan.cidr;
    staticsUplinkFails = !(staticsOk "10.10.10.0/29");
  };
  failed = lib.attrNames (lib.filterAttrs (_: ok: !ok) checks);
in
{
  perSystem =
    { pkgs, system, ... }:
    {
      checks = lib.optionalAttrs (system == "x86_64-linux") {
        kubernetes-lan = pkgs.runCommand "kubernetes-lan" { } ''
          failed=${lib.escapeShellArg (lib.concatStringsSep " " failed)}
          if [ -n "$failed" ]; then
            echo "kubernetes-lan: failed: $failed" >&2
            exit 1
          fi
          echo "kubernetes-lan: ${toString (lib.length (lib.attrNames checks))} properties hold over ${toString (lib.length lbServices)} LoadBalancer Services and ${toString (lib.length hostAddrs)} host addresses"
          touch $out
        '';
      };
    };
}
