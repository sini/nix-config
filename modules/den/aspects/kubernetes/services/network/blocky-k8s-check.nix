# The cluster resolver's pure check (docs/dns-resolver.md §2.7, tests 9 and 14,
# eval part), over axon's rendered blocky application. Each property has a
# control that must fail it:
#   ingress   DNS from world; DNS and the API from host/remote-node; the API from
#             10/8, the panel and Prometheus; nothing else. Controls: the
#             host/remote-node rule dropped, world admitted on 4000
#   egress    world on TCP 853 and 443, quad-100 on 53, the Valkey on 6379.
#             Controls: the Valkey rule dropped, world widened to 53
#   redis     the Valkey admits only the blocky pods on 6379. Control: from world
#   lb        a LoadBalancer on the cluster's `blocky` assignment, Local, on UDP/TCP
#             53 and TCP 4000. Controls: Cluster policy, the UDP port dropped
#   lan       a LoadBalancer `blocky-lan` on the `blocky-lan` assignment, Cluster
#             (L2 ignores endpoints), the L2 label, UDP/TCP 53 only; the resolver
#             record's dns is it and its api the `blocky` LB. Controls: Local
#             policy, port 4000 added
#   pods      3 replicas, one per node, no surge, the config's checksum on the pod.
#             Control: the checksum of another config
#   monitor   a ServiceMonitor on the Service's http port with job="blocky".
#             Control: the job left to the Service name
#   render    test 9's phase-2 render equality: the pods' config is uplink's but
#             for the instance inputs (listeners, CoreDNS address, cache path) and
#             the Valkey sync. Control: another denylist URL
#   validate  the config validates under the image's own binary (upstream
#             `latest`, which can run ahead of nixpkgs) and under uplink's
#   nix build .#checks.x86_64-linux.blocky-k8s
{ config, lib, ... }:
let
  axon = config.den.clusters.axon;
  lb = axon.networks.kubernetes-loadbalancers.assignments.blocky;
  lanLb = axon.networks.kubernetes-lan-loadbalancers.assignments.blocky-lan;
  record = config.den.aspects.kubernetes.services.network.blocky.dns-resolvers { cluster = axon; };
  coredns = axon.networks.kubernetes-services.assignments.coredns;
  uplink = config.flake.nixosConfigurations.uplink;

  # nixidy's typed resources carry every unset field as null.
  clean =
    v:
    if lib.isAttrs v then
      lib.mapAttrs (_: clean) (lib.filterAttrs (n: x: x != null && n != "_priority") v)
    else if lib.isList v then
      map clean v
    else
      v;
  objects = clean config.flake.nixidyEnvs.x86_64-linux.axon.config.applications.blocky.objects;
  get =
    kind: name:
    lib.findFirst (
      o: o.kind == kind && o.metadata.name == name
    ) (throw "blocky-k8s: no ${kind}/${name}") objects;
  cnp = n: (get "CiliumNetworkPolicy" n).spec;
  service = get "Service" "blocky";
  lanService = get "Service" "blocky-lan";
  deployment = get "Deployment" "blocky";
  monitor = get "ServiceMonitor" "blocky";
  configText = (get "ConfigMap" "blocky-config").data."config.yml";
  settings = builtins.fromJSON configText;

  port = protocol: p: {
    port = toString p;
    inherit protocol;
  };
  dns = [
    (port "UDP" 53)
    (port "TCP" 53)
  ];
  api = [ (port "TCP" 4000) ];
  blockyPods."app.kubernetes.io/name" = "blocky";
  redisPods."app.kubernetes.io/instance" = "blocky-redis";
  sameSet = a: b: lib.length a == lib.length b && lib.all (x: lib.elem x b) a;

  ingressOk =
    i:
    sameSet i [
      {
        fromEntities = [ "world" ];
        toPorts = [ { ports = dns; } ];
      }
      {
        fromEntities = [
          "host"
          "remote-node"
        ];
        toPorts = [ { ports = dns ++ api; } ];
      }
      {
        fromCIDR = [ "10.0.0.0/8" ];
        toPorts = [ { ports = api; } ];
      }
      {
        fromEndpoints = [
          {
            matchLabels = {
              "k8s:io.kubernetes.pod.namespace" = "blocky-ui";
              "app.kubernetes.io/name" = "blocky-ui";
            };
          }
        ];
        toPorts = [ { ports = api; } ];
      }
      {
        fromEndpoints = [
          {
            matchLabels = {
              "k8s:io.kubernetes.pod.namespace" = "monitoring";
              "app.kubernetes.io/name" = "prometheus";
            };
          }
        ];
        toPorts = [ { ports = api; } ];
      }
    ];
  ingress = cnp "allow-blocky-ingress";

  egressOk =
    e:
    sameSet e [
      {
        toEntities = [ "world" ];
        toPorts = [
          {
            ports = [
              (port "TCP" 853)
              (port "TCP" 443)
            ];
          }
        ];
      }
      {
        toCIDR = [ "100.100.100.100/32" ];
        toPorts = [ { ports = dns; } ];
      }
      {
        toEndpoints = [ { matchLabels = redisPods; } ];
        toPorts = [ { ports = [ (port "TCP" 6379) ]; } ];
      }
    ];
  egress = cnp "allow-blocky-egress";

  redisOk =
    p:
    p.endpointSelector.matchLabels == redisPods
    &&
      p.ingress == [
        {
          fromEndpoints = [ { matchLabels = blockyPods; } ];
          toPorts = [ { ports = [ (port "TCP" 6379) ]; } ];
        }
      ];
  redis = cnp "allow-blocky-redis-ingress";

  lbOk =
    s:
    s.spec.type == "LoadBalancer"
    && s.spec.externalTrafficPolicy == "Local"
    && s.metadata.annotations."lbipam.cilium.io/ips" == lb
    && sameSet (map (p: { inherit (p) port protocol; }) s.spec.ports) [
      {
        port = 53;
        protocol = "UDP";
      }
      {
        port = 53;
        protocol = "TCP";
      }
      {
        port = 4000;
        protocol = "TCP";
      }
    ];

  lanOk =
    s:
    s.spec.type == "LoadBalancer"
    && s.spec.externalTrafficPolicy == "Cluster"
    && s.metadata.annotations."lbipam.cilium.io/ips" == lanLb
    && lib.all (k: s.metadata.labels.${k} or null == (import ./cilium/_l2.nix).${k}) (
      lib.attrNames (import ./cilium/_l2.nix)
    )
    && sameSet (map (p: { inherit (p) port protocol; }) s.spec.ports) [
      {
        port = 53;
        protocol = "UDP";
      }
      {
        port = 53;
        protocol = "TCP";
      }
    ];

  podsOk =
    d: text:
    let
      spec = d.spec.template.spec;
    in
    d.spec.replicas == 3
    && d.spec.strategy.rollingUpdate.maxSurge == 0
    &&
      spec.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution == [
        {
          labelSelector.matchLabels = blockyPods;
          topologyKey = "kubernetes.io/hostname";
        }
      ]
    && d.spec.template.metadata.annotations."checksum/config" == builtins.hashString "sha256" text;

  monitorOk =
    m:
    m.spec.selector.matchLabels."app.kubernetes.io/service" == "blocky"
    && lib.any (p: p.name == "http" && p.port == 4000) service.spec.ports
    && lib.any (
      e:
      e.port == "http"
      && lib.any (r: r.targetLabel == "job" && r.replacement == "blocky") (e.relabelings or [ ])
    ) m.spec.endpoints;

  # The instance inputs and the Valkey sync are the only differences from uplink.
  instanceFree =
    s:
    lib.recursiveUpdate (removeAttrs s [
      "ports"
      "redis"
    ]) { blocking.loading.downloads.cachePath = null; }
    // {
      conditional.mapping = lib.attrNames s.conditional.mapping;
    };
  renderOk = s: instanceFree s == instanceFree uplink.config.services.blocky.settings;

  checks = {
    ingress = ingressOk ingress.ingress && ingress.endpointSelector.matchLabels == blockyPods;
    ingressNoHostFails =
      !(ingressOk (
        lib.filter (r: !(r ? fromEntities && lib.elem "host" r.fromEntities)) ingress.ingress
      ));
    ingressWorldApiFails =
      !(ingressOk (
        ingress.ingress
        ++ [
          {
            fromEntities = [ "world" ];
            toPorts = [ { ports = api; } ];
          }
        ]
      ));
    egress = egressOk egress.egress && egress.endpointSelector.matchLabels == blockyPods;
    egressNoRedisFails = !(egressOk (lib.filter (r: !(r ? toEndpoints)) egress.egress));
    egressWorldDnsFails =
      !(egressOk (
        map (r: if r ? toEntities then r // { toPorts = [ { ports = dns; } ]; } else r) egress.egress
      ));
    redis = redisOk redis;
    redisWorldFails =
      !(redisOk (redis // { ingress = redis.ingress ++ [ { fromEntities = [ "world" ]; } ]; }));
    lb = lbOk service;
    lbClusterFails = !(lbOk (lib.recursiveUpdate service { spec.externalTrafficPolicy = "Cluster"; }));
    lbNoUdpFails =
      !(lbOk (
        lib.recursiveUpdate service { spec.ports = lib.filter (p: p.protocol != "UDP") service.spec.ports; }
      ));
    lan = lanOk lanService;
    lanLocalFails = !(lanOk (lib.recursiveUpdate lanService { spec.externalTrafficPolicy = "Local"; }));
    lanApiFails =
      !(lanOk (
        lanService
        // {
          spec = lanService.spec // {
            ports = lanService.spec.ports ++ [
              {
                port = 4000;
                protocol = "TCP";
              }
            ];
          };
        }
      ));
    record = record.dns == lanLb && record.api == "http://${lb}:4000";
    pods = podsOk deployment configText;
    podsStaleChecksumFails = !(podsOk deployment (configText + " "));
    monitor = monitorOk monitor;
    monitorServiceJobFails =
      !(monitorOk (
        lib.recursiveUpdate monitor {
          spec.endpoints = map (e: removeAttrs e [ "relabelings" ]) monitor.spec.endpoints;
        }
      ));
    internalResolverIsClusterIp = lib.all (u: u == coredns) (
      lib.attrValues (
        removeAttrs settings.conditional.mapping [ "ts.${config.den.environments.prod.domain}" ]
      )
    );
    tailnetToQuad100 =
      settings.conditional.mapping."ts.${config.den.environments.prod.domain}" == "100.100.100.100";
    cacheOnEmptyDir =
      settings.blocking.loading.downloads.cachePath == "/cache"
      && lib.any (v: v.name == "cache" && v ? emptyDir) deployment.spec.template.spec.volumes;
    redisRequired =
      settings.redis == {
        address = "blocky-redis:6379";
        required = true;
        connectionAttempts = 10;
        connectionCooldown = "3s";
      }
      &&
        (get "Service" "blocky-redis").spec.ports == [
          {
            name = "tcp";
            port = 6379;
            protocol = "TCP";
            targetPort = "tcp";
          }
        ];
    render = renderOk settings;
    renderOtherListFails =
      !(renderOk (
        lib.recursiveUpdate settings {
          blocking.denylists.default = [ "https://example.invalid/list.txt" ];
        }
      ));
  };
  failed = lib.attrNames (lib.filterAttrs (_: ok: !ok) checks);
  image = config.flake.imagesDerivations.x86_64-linux."0xerr0r".blocky;
in
{
  perSystem =
    { pkgs, system, ... }:
    {
      checks = lib.optionalAttrs (system == "x86_64-linux") {
        blocky-k8s = pkgs.runCommand "blocky-k8s" { } ''
          failed=${lib.escapeShellArg (lib.concatStringsSep " " failed)}
          if [ -n "$failed" ]; then
            echo "blocky-k8s: failed: $failed" >&2
            exit 1
          fi
          # The image follows upstream `latest`, so it can run ahead of uplink's
          # nixpkgs Blocky while both render _settings.nix: the config must
          # validate under both binaries. The image's own is /app/blocky.
          mkdir image app
          tar -xf ${image} -C image
          for layer in $(${lib.getExe pkgs.jq} -r '.[0].Layers[]' image/manifest.json); do
            tar -xf "image/$layer" -C app --wildcards 'app/blocky' 2>/dev/null || true
          done
          test -x app/app/blocky || { echo "blocky-k8s: no /app/blocky in the image" >&2; exit 1; }
          for bin in app/app/blocky ${lib.getExe uplink.config.services.blocky.package}; do
            "$bin" version | grep Version
            "$bin" --config ${pkgs.writeText "config.yml" configText} validate
          done
          echo "blocky-k8s: ${toString (lib.length (lib.attrNames checks))} properties hold; the config validates under the image's and uplink's Blocky"
          touch $out
        '';
      };
    };
}
