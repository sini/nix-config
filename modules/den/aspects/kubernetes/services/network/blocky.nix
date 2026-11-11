# The environment's filtering resolver in the cluster (docs/dns-resolver.md
# §2.7): three Blocky replicas, one per node, behind two LoadBalancer addresses:
# `blocky-lan` on the prod LAN (Cilium L2, the clients' DNS) and `blocky` (BGP,
# the API, and DNS for routed clients). The config renders from the same _settings.nix as uplink's instance;
# this instance supplies its listeners, the CoreDNS ClusterIP and an emptyDir
# list cache. The replicas share blocking state through a Valkey in the same
# namespace (Blocky's redis sync), so one disable through the LB reaches all.
# Gating check: blocky-k8s-check.nix.
{ lib, ... }:
let
  name = "blocky";
  redisName = "blocky-redis";
  httpPort = 4000;
  render = import ../../../services/networking/blocky/_settings.nix { inherit lib; };
  pod."app.kubernetes.io/name" = name;
  # The valkey chart labels its pods app.kubernetes.io/instance=<release>.
  redisPod."app.kubernetes.io/instance" = redisName;
  port = protocol: p: {
    port = toString p;
    inherit protocol;
  };
  dnsPorts = [
    (port "UDP" 53)
    (port "TCP" 53)
  ];
  prometheusPods = {
    "k8s:io.kubernetes.pod.namespace" = "monitoring";
    "app.kubernetes.io/name" = "prometheus";
  };
  panelPods = {
    "k8s:io.kubernetes.pod.namespace" = "blocky-ui";
    "app.kubernetes.io/name" = "blocky-ui";
  };
  lbOf = cluster: cluster.getAssignment "blocky";
  lanOf = cluster: cluster.getAssignment "blocky-lan";
in
{
  den.aspects.kubernetes.services.network.blocky = {
    dns-resolvers =
      { cluster, ... }:
      {
        name = cluster.name;
        inherit (cluster) environment;
        # LAN clients reach the L2 address on-link; the API stays on the BGP one.
        dns = lanOf cluster;
        api = "http://${lbOf cluster}:${toString httpPort}";
      };

    k8s-manifests =
      {
        cluster,
        charts,
        images,
        environment,
        served-domains,
        ...
      }:
      let
        lb = lbOf cluster;
        settings =
          render {
            upstreams = environment.networks.default.dnsServers;
            # The names CoreDNS's hosts plugin answers (coredns.nix reads the same records).
            internalNames = lib.unique (
              lib.concatMap (r: r.domains) (lib.filter (r: r.environment == cluster.environment) served-domains)
            );
            internalResolver = cluster.getAssignment "coredns";
            tailnetDomain = "ts.${environment.domain}";
            cachePath = "/cache";
            inherit (environment.dns) filter;
            dnsListen = [ ":53" ];
            httpListen = [ ":${toString httpPort}" ];
          }
          // {
            # Required: a replica that can't sync would silently keep its own
            # blocking state, so it fails to start instead; running replicas reconnect.
            redis = {
              address = "${redisName}:6379";
              required = true;
              connectionAttempts = 10;
              connectionCooldown = "3s";
            };
          };
        config = builtins.toJSON settings;
      in
      {
        applications.${name} = {
          helm.releases.${name} = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              defaultPodOptions = {
                # The image runs as uid 100; this lets it bind :53 without a capability.
                securityContext = {
                  runAsNonRoot = true;
                  runAsUser = 100;
                  runAsGroup = 100;
                  sysctls = [
                    {
                      name = "net.ipv4.ip_unprivileged_port_start";
                      value = "53";
                    }
                  ];
                };
                # One replica per node, so every node advertises the LB address.
                affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution = [
                  {
                    labelSelector.matchLabels = pod;
                    topologyKey = "kubernetes.io/hostname";
                  }
                ];
              };
              controllers.main = {
                type = "deployment";
                replicas = 3;
                # No surge: a fourth pod has no node under the anti-affinity.
                strategy = "RollingUpdate";
                rollingUpdate = {
                  unavailable = 1;
                  surge = 0;
                };
                pod.annotations."checksum/config" = builtins.hashString "sha256" config;
                containers.main = {
                  image = {
                    inherit (images."0xerr0r/blocky") repository digest;
                  };
                  env.BLOCKY_CONFIG_FILE = "/config/config.yml";
                  securityContext = {
                    allowPrivilegeEscalation = false;
                    readOnlyRootFilesystem = true;
                    capabilities.drop = [ "ALL" ];
                  };
                  probes = lib.genAttrs [ "liveness" "readiness" ] (_: {
                    enabled = true;
                    custom = true;
                    spec.tcpSocket.port = 53;
                  });
                };
              };
              service.main = {
                controller = "main";
                primary = true;
                # Kept as `blocky` beside the second Service (the chart would suffix -main).
                forceRename = name;
                type = "LoadBalancer";
                # Local: only nodes with a replica advertise, and the client address
                # reaches the query log.
                externalTrafficPolicy = "Local";
                annotations."lbipam.cilium.io/ips" = lb;
                ports = {
                  dns-udp = {
                    port = 53;
                    protocol = "UDP";
                  };
                  dns-tcp = {
                    port = 53;
                    protocol = "TCP";
                  };
                  http.port = httpPort;
                };
              };
              # DNS on the LAN pool, ARP-announced by one node (cilium.nix). Cluster:
              # L2 announcements ignore endpoints, so Local could blackhole on a node
              # with no replica. PreferSameNode (cilium serviceTopology) sends the
              # announcing node's queries to its own replica, keeping the client
              # address; while that replica is not ready they go to another node's,
              # SNATed, and log the announcing node's address.
              service.lan = {
                controller = "main";
                type = "LoadBalancer";
                externalTrafficPolicy = "Cluster";
                trafficDistribution = "PreferSameNode";
                labels = import ./cilium/_l2.nix;
                annotations."lbipam.cilium.io/ips" = lanOf cluster;
                ports = {
                  dns-udp = {
                    port = 53;
                    protocol = "UDP";
                  };
                  dns-tcp = {
                    port = 53;
                    protocol = "TCP";
                  };
                };
              };
              persistence = {
                config = {
                  type = "configMap";
                  name = "${name}-config";
                  globalMounts = [
                    {
                      path = "/config/config.yml";
                      subPath = "config.yml";
                      readOnly = true;
                    }
                  ];
                };
                # Survives a container restart, not a reschedule (docs/dns-resolver.md §4).
                cache = {
                  type = "emptyDir";
                  globalMounts = [ { path = "/cache"; } ];
                };
              };
            };
          };

          # Pub/sub for blocking state and the cache; ephemeral. No password: Blocky's
          # API (unauthenticated, reachable from the LAN) already grants what a Valkey
          # client could do, and only the blocky pods may reach it (below).
          helm.releases.${redisName} = {
            chart = charts.valkey.valkey;
            values = {
              fullnameOverride = redisName;
              persistence.enabled = false;
              service.port = 6379;
            };
          };

          # prometheus-operator would name the job after the Service; pinned to the
          # job the dashboard and alerts read.
          objects = [
            {
              apiVersion = "monitoring.coreos.com/v1";
              kind = "ServiceMonitor";
              metadata = {
                inherit name;
                namespace = name;
              };
              spec = {
                selector.matchLabels."app.kubernetes.io/service" = name;
                endpoints = [
                  {
                    port = "http";
                    relabelings = [
                      {
                        action = "replace";
                        targetLabel = "job";
                        replacement = "blocky";
                      }
                    ];
                  }
                ];
              };
            }
          ];

          resources = {
            # JSON is YAML.
            configMaps."${name}-config".data."config.yml" = config;

            ciliumNetworkPolicies = {
              allow-blocky-ingress.spec = {
                description = "Blocky: DNS from anywhere routed to the LB; its API from the LAN, the nodes, the panel and Prometheus.";
                endpointSelector.matchLabels = pod;
                ingress = [
                  # LAN clients via blocky-lan arrive as world at the announcing node's
                  # replica, or SNATed to that node (remote-node, below) at another's.
                  {
                    fromEntities = [ "world" ];
                    toPorts = [ { ports = dnsPorts; } ];
                  }
                  # The axons query their own LB first; Cilium labels that host or remote-node.
                  {
                    fromEntities = [
                      "host"
                      "remote-node"
                    ];
                    toPorts = [ { ports = dnsPorts ++ [ (port "TCP" httpPort) ]; } ];
                  }
                  # The LB's off-cluster API clients (dns-filter), as the other internal LBs admit them.
                  {
                    fromCIDR = [ "10.0.0.0/8" ];
                    toPorts = [ { ports = [ (port "TCP" httpPort) ]; } ];
                  }
                  # The panel reaches the LB address, which resolves to these pods in-cluster.
                  {
                    fromEndpoints = [ { matchLabels = panelPods; } ];
                    toPorts = [ { ports = [ (port "TCP" httpPort) ]; } ];
                  }
                  {
                    fromEndpoints = [ { matchLabels = prometheusPods; } ];
                    toPorts = [ { ports = [ (port "TCP" httpPort) ]; } ];
                  }
                ];
              };
              allow-blocky-egress.spec = {
                description = "Blocky: DoT upstreams, list downloads, quad-100 for tailnet names, and its Valkey (CoreDNS comes from coredns.nix's grant).";
                endpointSelector.matchLabels = pod;
                egress = [
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
                    toPorts = [ { ports = dnsPorts; } ];
                  }
                  {
                    toEndpoints = [ { matchLabels = redisPod; } ];
                    toPorts = [ { ports = [ (port "TCP" 6379) ]; } ];
                  }
                ];
              };
              allow-blocky-redis-ingress.spec = {
                description = "blocky-redis: the blocky pods only.";
                endpointSelector.matchLabels = redisPod;
                ingress = [
                  {
                    fromEndpoints = [ { matchLabels = pod; } ];
                    toPorts = [ { ports = [ (port "TCP" 6379) ]; } ];
                  }
                ];
              };
            };
          };
        };
      };
  };
}
