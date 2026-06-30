# Shoko — AniDB-backed anime cataloging server.
#
# Complements the sonarr anime lane: sonarr acquires, shoko catalogs against
# AniDB IDs (and feeds Shokofin-style consumers later). Official image (not
# LSIO): config lives at /home/shoko/.shoko, so the config PVC mount path is
# overridden; PUID/PGID are honored. Mounts the shared media data PVC for
# import folders (configured in-app under /data).
#
# The service is described inline (formerly built via the mkMediaApp helper).
#
# AniDB talks over its own ports: UDP API on 9000/9002, HTTP API on 9001 —
# world egress for those rides an extra CNP next to the standard 80/443
# (artwork CDN) policy.
#
# Version pinned to v5.3.3 — latest stable. Bump in a dedicated pass.
{
  den.aspects.kubernetes.services.media.shoko = {
    service-domains = [ "shoko" ];

    age-secrets =
      { environment, ... }:
      {
        age.secrets.shoko-oidc-client-secret = {
          rekeyFile = environment.secretPath + "/oidc/shoko-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          sopsOutput = {
            file = "oidc";
            key = "shoko";
          };
        };
      };

    k8s-manifests =
      {
        config,
        cluster,
        charts,
        images,
        ...
      }:
      let
        # Private LB IP (kubernetes-loadbalancers pool) for the internal Shoko
        # API service below — BGP-advertised to the uplink host, not routable
        # from the internet.
        internalAddress = cluster.getAssignment "shoko-internal";

        # Alloy River config for the per-pod log-tail sidecar. Shoko (official
        # image, .NET / NLog) writes date-named log files under
        # /home/shoko/.shoko/Shoko.CLI/logs/<date>.log on the state PVC; the glob
        # `*.log` catches the active (current-day) file — older days are archived
        # to `<date>.zip`. Because the filename carries the date (the cardinality
        # driver), we collapse it to a bounded static `log_file = "shoko"` label
        # and drop the raw per-file `filename` label. The NLog line format is
        # `[<ts>] <Level>|<logger> > <msg>`; we lift the (title-case) level keyword.
        # The duplicate main-container stdout copy is dropped at the cluster
        # DaemonSet via the den.observability/file-tailed pod label.
        #
        # Rotation: Shoko's NLog target rolls files by date and self-prunes
        # (maxArchiveFiles) — not env-overridable, so we accept Shoko's default.
        #
        # The shoko user maps to PUID 1027 / PGID 65536 (confirmed live: it owns
        # /home/shoko/.shoko and the log files), so the logtail runs as 1027 to
        # read the logs and write its offset store under
        # /home/shoko/.shoko/.alloy on the state PVC.
        #
        # CRITICAL: validate any edit with `nix run nixpkgs#grafana-alloy -- fmt`.
        logtailConfig = ''
          logging {
            level = "warn"
          }

          local.file_match "logs" {
            path_targets = [{
              "__path__"  = "/home/shoko/.shoko/Shoko.CLI/logs/*.log",
              "app"       = "shoko",
              "namespace" = "media",
            }]
          }

          loki.source.file "logs" {
            targets    = local.file_match.logs.targets
            forward_to = [loki.process.logs.receiver]
          }

          loki.process "logs" {
            stage.regex {
              expression = "\\]\\s(?P<level>Trace|Debug|Info|Warn|Error|Fatal)\\|"
            }

            stage.labels {
              values = {
                level = "",
              }
            }

            // Bound stream cardinality: shoko names each day's log by date, so
            // the raw `filename` label grows daily. Collapse it to a static
            // app-level `log_file` label and drop the raw path.
            stage.static_labels {
              values = {
                log_file = "shoko",
              }
            }

            stage.label_drop {
              values = ["filename"]
            }

            forward_to = [loki.write.default.receiver]
          }

          loki.write "default" {
            endpoint {
              url = "http://loki.monitoring.svc:3100/loki/api/v1/push"
            }
          }
        '';
      in
      {
        applications.shoko = {
          namespace = "media";

          helm.releases.shoko = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.main = {
                type = "deployment";

                # Drives the cluster DaemonSet's stdout-drop for this pod's main
                # container (the logtail sidecar is the canonical log source).
                pod.labels."den.observability/file-tailed" = "true";

                containers.main = {
                  image = {
                    repository = "shokoanime/server";
                    tag = "v5.3.3";
                  };
                  env = {
                    TZ = "America/Los_Angeles";
                    PUID = "1027";
                    PGID = "65536";
                  };
                  envFrom = [ ];
                  probes = {
                    liveness = {
                      enabled = true;
                      type = "HTTP";
                      path = "/api/v3/Init/Status";
                      port = 8111;
                    };
                    readiness = {
                      enabled = true;
                      type = "HTTP";
                      path = "/api/v3/Init/Status";
                      port = 8111;
                    };
                  };
                };

                # Log-tail sidecar: tails the Shoko.CLI/logs/*.log files off the
                # state PVC and ships labeled, level-parsed streams to loki. The
                # grafana/alloy image entrypoint is the alloy binary, so args begin
                # with the `run` subcommand. Runs as the shoko uid (1027) so it can
                # read the logs and write its offset store on the state PVC.
                containers.logtail = {
                  image = {
                    inherit (images."grafana/alloy") repository digest;
                  };
                  args = [
                    "run"
                    "/etc/alloy/config.alloy"
                    # tail offsets on the state PVC -> survive pod restart
                    "--storage.path=/home/shoko/.shoko/.alloy"
                    # keep the alloy UI loopback-only (no CNP needed)
                    "--server.http.listen-addr=127.0.0.1:12345"
                  ];
                  securityContext = {
                    runAsUser = 1027;
                    runAsGroup = 65536;
                  };
                };
              };

              service.main = {
                controller = "main";
                # Pin the public service name to `shoko`: bjw-s suffixes every
                # service with its identifier once a controller owns >1 service
                # (main would become `shoko-main`), which would dangle the
                # HTTPRoute backendRef (-> `shoko`) below. forceRename keeps this
                # the byte-identical single-service name.
                forceRename = "shoko";
                ports.http.port = 8111;
              };

              # Internal-only LoadBalancer so off-cluster callers on the LAN can
              # reach Shoko's API directly, bypassing the OIDC-gated public route.
              # Jellyfin/Shokofin runs on the uplink host (outside the cluster)
              # and only speaks Shoko's native host + username/password login, so
              # it can't satisfy the Envoy OIDC SecurityPolicy on the public
              # `shoko` HTTPRoute. The LB IP comes from the private
              # kubernetes-loadbalancers pool (BGP-advertised to uplink, NOT
              # internet-routable — haproxy only SNI-forwards :443 to the
              # gateway), so the auth in front of it is Shoko's own API key.
              # externalTrafficPolicy=Local preserves the caller's real source
              # IP; the CNP below scopes ingress to the private LAN range.
              service.internal = {
                controller = "main";
                type = "LoadBalancer";
                externalTrafficPolicy = "Local";
                annotations."lbipam.cilium.io/ips" = internalAddress;
                ports.http.port = 8111;
              };

              # Sidecar Alloy River config delivered as a ConfigMap.
              configMaps.logtail.data."config.alloy" = logtailConfig;

              persistence = {
                # Mount the sidecar config into the logtail container only.
                logtail = {
                  type = "configMap";
                  identifier = "logtail";
                  advancedMounts.main.logtail = [
                    {
                      path = "/etc/alloy/config.alloy";
                      subPath = "config.alloy";
                      readOnly = true;
                    }
                  ];
                };
                # Official image keeps its state in /home/shoko/.shoko (no /config).
                config = {
                  type = "persistentVolumeClaim";
                  accessMode = "ReadWriteOnce";
                  size = "10Gi";
                  storageClass = "longhorn";
                  labels."recurring-job-group.longhorn.io/media-config" = "enabled";
                  globalMounts = [ { path = "/home/shoko/.shoko"; } ];
                };
                data = {
                  type = "persistentVolumeClaim";
                  existingClaim = "media-data-nfs";
                  globalMounts = [ { path = "/data"; } ];
                };
              };
            };
          };

          resources = {
            ciliumNetworkPolicies = {
              allow-gateway-ingress-shoko.spec = {
                description = "Allow Envoy Gateway proxies to reach shoko.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "shoko";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "8111";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              # Off-cluster LAN callers (e.g. Jellyfin/Shokofin on uplink) reach
              # Shoko over the internal LoadBalancer service above, bypassing the
              # OIDC gateway. Allow the whole private 10.0.0.0/8 range rather than
              # pinning a single host IP: it's portable (any LAN host, no
              # per-deployment IP), the LB IP is RFC1918 / not internet-routable,
              # and Shoko's own login is the auth in front. The wide CIDR also
              # covers both the externalTrafficPolicy=Local source (the caller's
              # real IP) and any future node-SNAT (a cluster node's 10.x address).
              allow-lan-ingress-shoko.spec = {
                description = "Allow private-LAN clients (e.g. Jellyfin/Shokofin) to reach shoko on 8111, bypassing the OIDC gateway.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "shoko";
                ingress = [
                  {
                    fromCIDR = [ "10.0.0.0/8" ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "8111";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              allow-dns-egress-shoko.spec = {
                description = "Allow shoko to resolve via kube-dns.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "shoko";
                egress = [
                  {
                    toEndpoints = [
                      {
                        matchLabels = {
                          "k8s:io.kubernetes.pod.namespace" = "kube-system";
                          "k8s-app" = "kube-dns";
                        };
                      }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "53";
                            protocol = "UDP";
                          }
                          {
                            port = "53";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              # Artwork/banner CDNs over HTTPS.
              allow-internet-egress-shoko.spec = {
                description = "Allow shoko to reach the public internet.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "shoko";
                egress = [
                  {
                    toEntities = [ "world" ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "80";
                            protocol = "TCP";
                          }
                          {
                            port = "443";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              allow-anidb-egress-shoko.spec = {
                description = "Allow shoko to reach the AniDB UDP (9000, 9002) and HTTP (9001) APIs.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "shoko";
                egress = [
                  {
                    toEntities = [ "world" ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "9000";
                            protocol = "UDP";
                          }
                          {
                            port = "9001";
                            protocol = "TCP";
                          }
                          {
                            port = "9002";
                            protocol = "UDP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };
            };

            httpRoutes.shoko.spec = {
              hostnames = [ (cluster.domainFor "shoko") ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "shoko"}-https";
                }
              ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "shoko";
                      port = 8111;
                    }
                  ];
                }
              ];
            };

            securityPolicies."shoko-oidc".spec = {
              targetRefs = [
                {
                  group = "gateway.networking.k8s.io";
                  kind = "HTTPRoute";
                  name = "shoko";
                }
              ];
              oidc = {
                provider.issuer = cluster.secrets.oidcIssuerFor "shoko";
                clientID = "shoko";
                clientSecret.name = "shoko-oidc-client-secret";
                scopes = [
                  "email"
                  "openid"
                  "profile"
                ];
                forwardAccessToken = true;
              };
            };

            secrets.shoko-oidc-client-secret = {
              type = "Opaque";
              stringData.client-secret = config.age.secrets.shoko-oidc-client-secret.sopsRef;
            };
          };
        };
      };
  };
}
