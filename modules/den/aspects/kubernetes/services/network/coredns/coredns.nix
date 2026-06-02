# CoreDNS — dual-stack, forward to env DNS, prometheus metrics 9153, cache 30s.
#
# Ported from main:modules/kubernetes/services/network/coredns/coredns.nix
{
  lib,
  config,
  ...
}:
let
  environments = config.den.environments;
in
{
  den.aspects.kubernetes.services.network.coredns = {
    k8s-manifests =
      { cluster, charts, ... }:
      let
        environment = environments.${cluster.environment};
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
                  zones = [
                    { zone = "."; }
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
