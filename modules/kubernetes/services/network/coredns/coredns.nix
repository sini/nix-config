{ lib, ... }:
{
  flake.kubernetes.services.coredns = {

    options = {
      clusterIP = lib.mkOption {
        type = lib.types.str;
        description = "CoreDNS ClusterIP address allocation";
      };
    };

    nixidy =
      { config, charts, ... }:
      {
        applications.coredns = {
          namespace = "kube-system";
          annotations."argocd.argoproj.io/sync-wave" = "-2";

          helm.releases.coredns = {
            chart = charts.coredns.coredns;
            values = {
              service.clusterIP = config.kubernetes.services.coredns.clusterIP;
              servers = [
                {
                  zones = [
                    {
                      zone = ".";
                      # scheme = ""; # Default: dns://
                      # useTCP = true;
                    }
                  ];
                  port = 53;
                  plugins = [
                    {
                      name = "errors";
                      config = {
                        # No configuration needed for errors plugin
                      };
                    }
                    {
                      name = "health";
                      config = {
                        lameduck = "5s";
                      };
                    }
                    {
                      name = "ready";
                    }
                    {
                      name = "kubernetes";
                      parameters = "cluster.local cluster.local in-addr.arpa ip6.arpa";
                      configBlock = ''
                        pods insecure
                        fallthrough in-addr.arpa ip6.arpa
                        ttl 30
                      '';
                    }
                    {
                      name = "prometheus";
                      parameters = "0.0.0.0:9153";
                    }
                    {
                      name = "template"; # Filter IPv6 results since we're not currently dual stack...
                      parameters = "IN AAAA .";
                      configBlock = ''
                        rcode NOERROR
                      '';
                    }
                    {
                      name = "forward";
                      parameters = ". 1.1.1.1";
                      config = {
                        policy = "sequential";
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
                    {
                      name = "loop";
                    }
                    {
                      name = "reload";
                    }
                    {
                      name = "loadbalance";
                    }
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
                              port = "53"; # Plain DNS
                              protocol = "UDP";
                            }
                            {
                              port = "853"; # Secure DNS
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
