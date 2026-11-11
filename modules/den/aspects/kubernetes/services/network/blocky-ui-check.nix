# The admin panel's pure check (docs/dns-resolver.md §2.6, test 15), over axon's
# nixidy resources and uplink's kanidm. Each property has a control that must fail it:
#   oidc     every route at dns.<domain> is the panel's, and an OIDC SecurityPolicy
#            targets it; controls: the policy without oidc, the policy aimed at
#            another route, a second route on the name
#   admins   the policy's client is blocky-ui, whose only scope map is admins;
#            controls: a media.access map added, the oauth2-proxy client
#   egress   the pod's one egress policy allows exactly 10.10.10.1/32 TCP 4000
#            (uplink's Blocky API) and the cluster's blocky pods on TCP 4000 (its LB
#            address is translated to them before policy), and the panel's servers
#            are exactly those two; controls: a world rule added, the port widened
#            to a range, a /24
#   ingress  only the gateways namespace, on the panel's port; control: from world
#   uplink   uplink serves no dns.<domain> vhost and runs no blocky-ui container;
#            control: the vhost added back
#   nix build .#checks.x86_64-linux.blocky-ui
{ config, lib, ... }:
let
  app = config.flake.nixidyEnvs.x86_64-linux.axon.config.applications.blocky-ui;
  uplink = config.flake.nixosConfigurations.uplink.config;
  domain = config.den.environments.prod.getDomainFor "dns";
  clients = uplink.services.kanidm.provision.systems.oauth2;

  # nixidy's typed resources carry every unset field as null.
  clean =
    v:
    if lib.isAttrs v then
      lib.mapAttrs (_: clean) (lib.filterAttrs (n: x: x != null && n != "_priority") v)
    else if lib.isList v then
      map clean v
    else
      v;
  res = clean {
    inherit (app.resources)
      httpRoutes
      securityPolicies
      ciliumNetworkPolicies
      configMaps
      ;
  };
  sameSet = a: b: lib.length a == lib.length b && lib.all (x: lib.elem x b) a;
  axonLb = config.den.clusters.axon.networks.kubernetes-loadbalancers.assignments.blocky;
  blockyPods = {
    "k8s:io.kubernetes.pod.namespace" = "blocky";
    "app.kubernetes.io/name" = "blocky";
  };
  selectsPanel =
    p: (p.spec.endpointSelector.matchLabels or { }) == { "app.kubernetes.io/name" = "blocky-ui"; };
  tcp = port: [
    {
      ports = [
        {
          inherit port;
          protocol = "TCP";
        }
      ];
    }
  ];

  oidcOk =
    r:
    let
      onName = lib.filterAttrs (_: h: lib.elem domain (h.spec.hostnames or [ ])) r.httpRoutes;
      guarded = lib.filter (
        p: p.spec ? oidc && lib.any (t: t.kind == "HTTPRoute" && t.name == "blocky-ui") p.spec.targetRefs
      ) (lib.attrValues r.securityPolicies);
    in
    lib.attrNames onName == [ "blocky-ui" ] && lib.length guarded == 1;

  adminsOk =
    r: cs:
    let
      p = lib.head (lib.attrValues r.securityPolicies);
    in
    lib.length (lib.attrValues r.securityPolicies) == 1
    && p.spec.oidc.clientID == "blocky-ui"
    && lib.attrNames (cs.${p.spec.oidc.clientID}.scopeMaps or { }) == [ "admins" ];

  egressOk =
    r:
    let
      ps = lib.filter (p: selectsPanel p && p.spec ? egress) (lib.attrValues r.ciliumNetworkPolicies);
    in
    lib.length ps == 1
    && sameSet (lib.head ps).spec.egress [
      {
        toCIDR = [ "10.10.10.1/32" ];
        toPorts = tcp "4000";
      }
      {
        toEndpoints = [ { matchLabels = blockyPods; } ];
        toPorts = tcp "4000";
      }
    ]
    &&
      sameSet
        (lib.attrValues (builtins.fromJSON r.configMaps.blocky-ui-config.data."blocky-ui.yml").servers)
        [
          {
            name = "uplink";
            url = "http://10.10.10.1:4000";
          }
          {
            name = "axon";
            url = "http://${axonLb}:4000";
          }
        ];

  ingressOk =
    r:
    let
      ps = lib.filter (p: selectsPanel p && p.spec ? ingress) (lib.attrValues r.ciliumNetworkPolicies);
    in
    lib.length ps == 1
    &&
      (lib.head ps).spec.ingress == [
        {
          fromEndpoints = [ { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; } ];
          toPorts = tcp "3000";
        }
      ];

  uplinkOk =
    vhosts: !(vhosts ? ${domain}) && !(uplink.virtualisation.oci-containers.containers ? blocky-ui);

  at = path: update: lib.updateManyAttrsByPath [ { inherit path update; } ] res;
  egressAt = at [
    "ciliumNetworkPolicies"
    "allow-blocky-ui-api-egress"
    "spec"
    "egress"
  ];

  checks = {
    oidc = oidcOk res;
    oidcNoOidcFails =
      !(oidcOk (at [ "securityPolicies" "blocky-ui-oidc" "spec" ] (s: removeAttrs s [ "oidc" ])));
    oidcOtherRouteFails =
      !(oidcOk (
        at [ "securityPolicies" "blocky-ui-oidc" "spec" "targetRefs" ] (map (t: t // { name = "other"; }))
      ));
    oidcSecondRouteFails = !(oidcOk (at [ "httpRoutes" "open" ] (_: res.httpRoutes.blocky-ui)));
    admins = adminsOk res clients;
    adminsMediaFails =
      !(adminsOk res (
        lib.recursiveUpdate clients { blocky-ui.scopeMaps."media.access" = [ "openid" ]; }
      ));
    adminsOauth2ProxyFails =
      !(adminsOk (at [ "securityPolicies" "blocky-ui-oidc" "spec" "oidc" "clientID" ] (
        _: "oauth2-proxy"
      )) clients);
    egress = egressOk res;
    egressWorldFails = !(egressOk (egressAt (e: e ++ [ { toEntities = [ "world" ]; } ])));
    egressRangeFails =
      !(egressOk (
        egressAt (
          map (
            e:
            e
            // {
              toPorts = [
                {
                  ports = [
                    {
                      port = "4000";
                      endPort = 4100;
                      protocol = "TCP";
                    }
                  ];
                }
              ];
            }
          )
        )
      ));
    egressSubnetFails = !(egressOk (egressAt (map (e: e // { toCIDR = [ "10.10.10.0/24" ]; }))));
    ingress = ingressOk res;
    ingressWorldFails =
      !(ingressOk (
        at [ "ciliumNetworkPolicies" "allow-gateway-ingress-blocky-ui" "spec" "ingress" ] (
          i: i ++ [ { fromEntities = [ "world" ]; } ]
        )
      ));
    uplink = uplinkOk uplink.services.nginx.virtualHosts;
    uplinkVhostFails = !(uplinkOk (uplink.services.nginx.virtualHosts // { ${domain} = { }; }));
  };
  failed = lib.attrNames (lib.filterAttrs (_: ok: !ok) checks);
in
{
  perSystem =
    { pkgs, system, ... }:
    {
      checks = lib.optionalAttrs (system == "x86_64-linux") {
        blocky-ui = pkgs.runCommand "blocky-ui" { } ''
          failed=${lib.escapeShellArg (lib.concatStringsSep " " failed)}
          if [ -n "$failed" ]; then
            echo "blocky-ui: failed: $failed" >&2
            exit 1
          fi
          echo "blocky-ui: ${toString (lib.length (lib.attrNames checks))} properties hold"
          touch $out
        '';
      };
    };
}
