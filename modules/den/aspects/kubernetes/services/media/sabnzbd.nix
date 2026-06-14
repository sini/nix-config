# SABnzbd — Usenet (NZB) download client for the media stack.
#
# Routed + OIDC-protected UI on nzb.json64.dev (NOT the default
# sabnzbd.json64.dev): prod.nix declares `services.sabnzbd.domain =
# "nzb.json64.dev"` and `cluster.domainFor "sabnzbd"` picks it up. The OIDC
# clientID stays "sabnzbd".
#
# Storage: scratch-local ONLY (RWO `media-scratch-local` PVC → /scratch). The
# RWO claim co-schedules SABnzbd onto the same node (axon-01) as the other
# scratch-local pods (qBittorrent), keeping completed downloads on fast local
# disk. SAB writes its work under /scratch/usenet/{incomplete,complete}; it has
# NO /data mount — the *arrs import from the NFS scratch view, not from SAB.
#
# API key: SAB reads its key from sabnzbd.ini, not from env. We seed the ini via
# an init container (controllers.main.initContainers.config-seed) that, on a
# fresh /config, writes a minimal ini wiring the api_key from the shared
# media-arr-api-keys secret (so the *arrs can register against SAB
# deterministically) + host_whitelist + the /scratch download dirs; on an
# existing /config it rewrites the api_key and ensures host_whitelist. The
# script is idempotent. See the inline script for every ini key touched.
#
# Networking: besides the gateway-ingress + DNS-egress baselines, SAB needs
# world egress to Usenet providers (NNTP 119 / NNTPS 563) and to indexers / SSL
# providers (443). The internet-egress policy opens 80/443 plus the NNTP ports.
#
# The service is described inline (formerly built via the mkMediaApp helper).
#
# Version: the media-user backup carries no SABnzbd version marker (the ini has
# no version field), so we pin to the latest stable LSIO tag (5.0.4) rather than
# `latest`. Bump tags in the dedicated deploy-time pass.
{
  den.aspects.kubernetes.services.media.sabnzbd = {
    service-domains = [ "sabnzbd" ];

    age-secrets =
      { environment, ... }:
      {
        age.secrets.sabnzbd-oidc-client-secret = {
          rekeyFile = environment.secretPath + "/oidc/sabnzbd-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          sopsOutput = {
            file = "oidc";
            key = "sabnzbd";
          };
        };
      };

    k8s-manifests =
      {
        config,
        cluster,
        charts,
        ...
      }:
      let
        # Minimal sabnzbd.ini seeder. Idempotent:
        #   fresh /config  -> write a minimal [misc] section
        #   existing       -> rewrite api_key + ensure host_whitelist line
        # ini keys touched (all under [misc]):
        #   api_key        — fixed key from media-arr-api-keys/sabnzbd (env API_KEY)
        #   host_whitelist — nzb.json64.dev (+ in-cluster short name `sabnzbd`) so
        #                    SAB accepts the proxied Host header from the gateway
        #   host/port      — bind all interfaces on 8080
        #   download_dir   — /scratch/usenet/incomplete
        #   complete_dir   — /scratch/usenet/complete
        # printf (not a heredoc) so this survives Nix indented-string dedenting —
        # no column-0 sensitivity.
        configSeedScript = ''
          set -eu
          INI=/config/sabnzbd.ini
          WHITELIST="nzb.json64.dev, sabnzbd"
          mkdir -p /scratch/usenet/incomplete /scratch/usenet/complete
          if [ ! -f "$INI" ]; then
            echo "seeding fresh $INI"
            {
              printf '%s\n' '[misc]'
              printf '%s\n' 'host = 0.0.0.0'
              printf '%s\n' 'port = 8080'
              printf '%s\n' "api_key = $API_KEY"
              printf '%s\n' "host_whitelist = $WHITELIST"
              printf '%s\n' 'inet_exposure = 4'
              printf '%s\n' 'download_dir = /scratch/usenet/incomplete'
              printf '%s\n' 'complete_dir = /scratch/usenet/complete'
            } > "$INI"
          else
            echo "reconciling existing $INI"
            # sed "/^\[misc\]/a ..." silently no-ops if [misc] is absent (set -e can't
            # catch it), so ensure the section exists before any append below.
            grep -q '^\[misc\]' "$INI" || printf '[misc]\n' >> "$INI"
            if grep -q '^api_key = ' "$INI"; then
              sed -i "s|^api_key = .*|api_key = $API_KEY|" "$INI"
            else
              sed -i "/^\[misc\]/a api_key = $API_KEY" "$INI"
            fi
            if grep -q '^host_whitelist = ' "$INI"; then
              sed -i "s|^host_whitelist = .*|host_whitelist = $WHITELIST|" "$INI"
            else
              sed -i "/^\[misc\]/a host_whitelist = $WHITELIST" "$INI"
            fi
            # inet_exposure 4 = WebUI reachable from non-local clients (the gateway's
            # pod network); without it SAB answers "External internet access denied".
            if grep -q '^inet_exposure = ' "$INI"; then
              sed -i "s|^inet_exposure = .*|inet_exposure = 4|" "$INI"
            else
              sed -i "/^\[misc\]/a inet_exposure = 4" "$INI"
            fi
          fi
        '';
      in
      {
        applications.sabnzbd = {
          namespace = "media";

          helm.releases.sabnzbd = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.main = {
                type = "deployment";

                # Seed/reconcile sabnzbd.ini before the main container starts.
                # Runs the SAB image (same UID handling) so /config ownership
                # stays consistent.
                initContainers.config-seed = {
                  image = {
                    repository = "lscr.io/linuxserver/sabnzbd";
                    tag = "5.0.4";
                  };
                  command = [
                    "/bin/sh"
                    "-c"
                    configSeedScript
                  ];
                  env.API_KEY.valueFrom.secretKeyRef = {
                    name = "media-arr-api-keys";
                    key = "sabnzbd";
                  };
                };

                containers.main = {
                  image = {
                    repository = "lscr.io/linuxserver/sabnzbd";
                    tag = "5.0.4";
                  };
                  env = {
                    TZ = "America/Los_Angeles";
                    PUID = "1027";
                    PGID = "65536";
                  };
                  envFrom = [ ];
                  # SAB serves its UI on the web port; default probe is fine.
                  probes = {
                    liveness = {
                      enabled = true;
                      type = "HTTP";
                      path = "/";
                      port = 8080;
                    };
                    readiness = {
                      enabled = true;
                      type = "HTTP";
                      path = "/";
                      port = 8080;
                    };
                  };
                };
              };

              service.main = {
                controller = "main";
                ports.http.port = 8080;
              };

              persistence = {
                config = {
                  type = "persistentVolumeClaim";
                  accessMode = "ReadWriteOnce";
                  size = "1Gi";
                  storageClass = "longhorn";
                  labels."recurring-job-group.longhorn.io/media-config" = "enabled";
                  globalMounts = [ { path = "/config"; } ];
                };
                # scratch-local RWO → /scratch (pins pod to the scratch node).
                # No /data.
                scratch = {
                  type = "persistentVolumeClaim";
                  existingClaim = "media-scratch-local";
                  globalMounts = [ { path = "/scratch"; } ];
                };
              };
            };
          };

          resources = {
            ciliumNetworkPolicies = {
              allow-gateway-ingress-sabnzbd.spec = {
                description = "Allow Envoy Gateway proxies to reach sabnzbd.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "sabnzbd";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "8080";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              allow-dns-egress-sabnzbd.spec = {
                description = "Allow sabnzbd to resolve via kube-dns.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "sabnzbd";
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

              # World egress (80/443) plus NNTP (119) / NNTPS (563): SAB reaches
              # Usenet providers on the NNTP ports and indexers / SSL providers on
              # 80/443.
              allow-internet-egress-sabnzbd.spec = {
                description = "Allow sabnzbd to reach the public internet.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "sabnzbd";
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
                          {
                            port = "119";
                            protocol = "TCP";
                          }
                          {
                            port = "563";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };
            };

            httpRoutes.sabnzbd.spec = {
              hostnames = [ (cluster.domainFor "sabnzbd") ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "sabnzbd"}-https";
                }
              ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "sabnzbd";
                      port = 8080;
                    }
                  ];
                }
              ];
            };

            securityPolicies."sabnzbd-oidc".spec = {
              targetRefs = [
                {
                  group = "gateway.networking.k8s.io";
                  kind = "HTTPRoute";
                  name = "sabnzbd";
                }
              ];
              oidc = {
                provider.issuer = cluster.secrets.oidcIssuerFor "sabnzbd";
                clientID = "sabnzbd";
                clientSecret.name = "sabnzbd-oidc-client-secret";
                scopes = [
                  "email"
                  "openid"
                  "profile"
                ];
                forwardAccessToken = true;
              };
            };

            secrets.sabnzbd-oidc-client-secret = {
              type = "Opaque";
              stringData.client-secret = config.age.secrets.sabnzbd-oidc-client-secret.sopsRef;
            };
          };
        };
      };
  };
}
