# CoreDNS — dual-stack, forward to env DNS, prometheus metrics 9153, cache 30s.
{
  den.aspects.kubernetes.services.network.coredns = {
    k8s-manifests =
      {
        cluster,
        charts,
        environment,
        lib,
        ...
      }:
      let
        defaultNetwork =
          environment.networks.default or {
            dnsServers = [
              "1.1.1.1"
              "8.8.8.8"
            ];
          };
      in
      {
        applications.coredns = {
          namespace = "kube-system";
          annotations."argocd.argoproj.io/sync-wave" = "-2";

          helm.releases.coredns = {
            chart = charts.coredns.coredns;
            values = {
              # Two replicas: removes the single-point-of-failure for cluster DNS
              # and makes config rolls (e.g. the use_tcp change below) non-disruptive.
              replicaCount = 2;

              service = {
                k8sAppLabelOverride = "kube-dns";
                clusterIP = cluster.getAssignment "coredns";
                ipFamilyPolicy = "RequireDualStack";
                ipFamilies = [
                  "IPv4"
                  "IPv6"
                ];
              };
              servers = [
                {
                  # use_tcp makes the chart emit a TCP/53 Service + container port
                  # (its servicePorts helper only adds TCP for a dns:// zone when
                  # use_tcp=true). Without it the Service is UDP/53-only, so glibc's
                  # TCP fallback for truncated/large answers blackholes — cold
                  # external names (e.g. OIDC discovery hosts) fail with a ~10s
                  # timeout on the first search-domain leg. DNS-over-TCP is mandatory
                  # (RFC 7766).
                  zones = [
                    {
                      zone = ".";
                      use_tcp = true;
                    }
                  ];
                  port = 53;
                  plugins = [
                    {
                      name = "errors";
                      config = { };
                    }
                    {
                      name = "health";
                      config.lameduck = "5s";
                    }
                    { name = "ready"; }
                    {
                      name = "kubernetes";
                      parameters = "cluster.local cluster.local in-addr.arpa ip6.arpa";
                      config = {
                        pods = "insecure";
                        fallthrough = "in-addr.arpa ip6.arpa";
                        ttl = 30;
                      };
                    }
                    {
                      name = "prometheus";
                      parameters = "0.0.0.0:9153";
                    }
                    {
                      name = "forward";
                      parameters = ". ${lib.concatStringsSep " " (lib.lists.take 3 defaultNetwork.dnsServers)}";
                      config = {
                        max_concurrent = 1000;
                        policy = "sequential";
                        health_check = "5s";
                        expire = "10s";
                        prefer_udp = true;
                      };
                    }
                    {
                      name = "cache";
                      parameters = "30";
                      config = {
                        success = 9984;
                        denial = 9984;
                        prefetch = 1;
                      };
                    }
                    { name = "loop"; }
                    { name = "reload"; }
                    { name = "loadbalance"; }
                  ];
                }
              ];
            };
          };

          resources = {
            ciliumNetworkPolicies = {
              # Allow kube-dns to talk to upstream DNS
              allow-kube-dns-upstream-egress = {
                metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
                spec = {
                  description = "Policy for egress to allow kube-dns to talk to upstream DNS.";
                  endpointSelector.matchLabels."app.kubernetes.io/name" = "coredns";
                  egress = [
                    {
                      toEntities = [ "world" ];
                      toPorts = [
                        {
                          ports = [
                            {
                              port = "53";
                              protocol = "UDP";
                            }
                            # TCP/53 so coredns can retry truncated upstream answers
                            # over TCP (mirrors the in-cluster TCP/53 ingress).
                            {
                              port = "53";
                              protocol = "TCP";
                            }
                            {
                              port = "853";
                              protocol = "UDP";
                            }
                          ];
                        }
                      ];
                    }
                  ];
                };
              };

              # Allow CoreDNS to talk to kube-apiserver
              allow-kube-dns-apiserver-egress = {
                metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
                spec = {
                  description = "Allow coredns to talk to kube-apiserver.";
                  endpointSelector.matchLabels."app.kubernetes.io/name" = "coredns";
                  egress = [
                    {
                      toEntities = [ "kube-apiserver" ];
                      toPorts = [
                        {
                          ports = [
                            {
                              port = "6443";
                              protocol = "TCP";
                            }
                          ];
                        }
                      ];
                    }
                  ];
                };
              };
            };

            ciliumClusterwideNetworkPolicies.allow-kube-dns-cluster-ingress = {
              metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
              spec = {
                description = "Policy for ingress allow to coredns from all Cilium managed endpoints in the cluster.";
                endpointSelector.matchLabels = {
                  "k8s:io.kubernetes.pod.namespace" = "kube-system";
                  "app.kubernetes.io/name" = "coredns";
                };
                ingress = [
                  {
                    fromEndpoints = [ { } ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "53";
                            protocol = "UDP";
                          }
                          # TCP/53 for glibc's TCP fallback on truncated/large DNS
                          # answers; without it those retries are dropped.
                          {
                            port = "53";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                  # prometheus -> coredns metrics (Corefile prometheus plugin)
                  {
                    fromEndpoints = [
                      {
                        matchLabels = {
                          "k8s:io.kubernetes.pod.namespace" = "monitoring";
                          "app.kubernetes.io/name" = "prometheus";
                        };
                      }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "9153";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };
            };
          };
        };
      };
  };
}
