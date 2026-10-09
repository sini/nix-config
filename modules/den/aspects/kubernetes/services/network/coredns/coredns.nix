# CoreDNS — dual-stack, forward to env DNS, prometheus metrics 9153, cache 30s.
# Gating check: dns-egress-check.nix, over the rendered manifests.
{ lib, ... }:
{
  den.aspects.kubernetes.services.network.coredns = {
    settings.staticHosts = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Extra fqdn -> IPv4 answers for the CoreDNS `hosts` plugin, merged over
        (and overriding) the collected served-domains records.
      '';
    };

    k8s-manifests =
      {
        cluster,
        charts,
        environment,
        served-domains,
        lib,
        ...
      }:
      let
        # Every served name answers with its internal address (a host's LAN IP
        # or the gateway VIP), so in-cluster clients reach it directly instead of
        # hairpinning through Cloudflare and the router.
        staticHosts =
          lib.listToAttrs (
            lib.concatMap (r: map (d: lib.nameValuePair d r.address) r.domains) (
              lib.filter (r: r.environment == cluster.environment) served-domains
            )
          )
          // cluster.settings.kubernetes.services.network.coredns.staticHosts;
        defaultNetwork =
          environment.networks.default or {
            dnsServers = [
              "1.1.1.1"
              "8.8.8.8"
            ];
          };
        # The CoreDNS pods as the chart labels them (k8s-app=coredns); only the
        # Service carries k8s-app=kube-dns, so a pod selector on that matches
        # nothing. Both cluster-wide DNS policies below select through this.
        corednsPods = {
          "k8s:io.kubernetes.pod.namespace" = "kube-system";
          "app.kubernetes.io/name" = "coredns";
        };
        # TCP/53 for glibc's TCP fallback on truncated/large DNS answers;
        # without it those retries are dropped.
        dnsPorts = [
          {
            port = "53";
            protocol = "UDP";
          }
          {
            port = "53";
            protocol = "TCP";
          }
        ];
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
                    # The chart renders a plugin's inner block from `configBlock` (a
                    # `config` attrset is ignored). No trailing newline: it would end
                    # the Corefile in an indented blank line, which turns its YAML
                    # block scalar into a quoted string.
                    {
                      name = "hosts";
                      configBlock = lib.concatStringsSep "\n" (
                        lib.mapAttrsToList (domain: address: "${address} ${domain}") staticHosts ++ [ "fallthrough" ]
                      );
                    }
                    {
                      name = "forward";
                      # Plain DNS to the addresses; resolved's "#tls-name" suffix is dropped.
                      parameters = ". ${
                        lib.concatStringsSep " " (
                          map (s: lib.head (lib.splitString "#" s)) (lib.lists.take 3 defaultNetwork.dnsServers)
                        )
                      }";
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

            # The egress half: every endpoint may reach CoreDNS on 53, so no app
            # declares its own DNS egress. L4 only, so no DNS is proxied
            # cluster-wide; a namespace that needs the proxy (toFQDNs, e.g.
            # genie-eval) adds its own L7 rule. Default deny is left untouched:
            # this policy only adds an allow, it never puts an endpoint into
            # egress enforcement.
            ciliumClusterwideNetworkPolicies.allow-kube-dns-cluster-egress = {
              metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
              spec = {
                description = "Policy for egress allow to coredns from all Cilium managed endpoints in the cluster.";
                endpointSelector = { };
                enableDefaultDeny = {
                  egress = false;
                  ingress = false;
                };
                egress = [
                  {
                    toEndpoints = [ { matchLabels = corednsPods; } ];
                    toPorts = [ { ports = dnsPorts; } ];
                  }
                ];
              };
            };

            ciliumClusterwideNetworkPolicies.allow-kube-dns-cluster-ingress = {
              metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
              spec = {
                description = "Policy for ingress allow to coredns from all Cilium managed endpoints in the cluster.";
                endpointSelector.matchLabels = corednsPods;
                ingress = [
                  {
                    fromEndpoints = [ { } ];
                    toPorts = [ { ports = dnsPorts; } ];
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
