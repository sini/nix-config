# searxng — the fleet's metasearch service. Three ways in, each on an existing
# convention, and nothing public:
#
#   genie tier 1   in-cluster ClusterIP, http://searxng.search.svc.cluster.local:8080
#                  (genie-agent src/tier1/web.ts: GET <url>/search?q=…&format=json)
#   fleet hosts    the internal LoadBalancer `searxng-internal` (axon.nix assignments),
#                  BGP-advertised to the LAN and not internet-routable — the
#                  hindsight/shoko idiom for headless API clients, which the
#                  OIDC gateway would turn away
#   people         https://search.<domain> on the default gateway behind kanidm
#                  OIDC, granted to `search.access` (every user)
#
# Chart: littleoffice/searxng (rootless, read-only root, no init containers), image
# pinned by the image updater. Its settings.yml and secret_key come only from a
# Secret it is pointed at, and both live in one here: settings.yml is no secret, so
# it rides as plain stringData; secret-key is a generated token.
#
# Engines: SearXNG's defaults narrowed with `keep_only` to keyless engines that
# answer what the fleet asks, from the cluster's egress address (the site's
# residential IP, not a datacenter one). Each one's endpoints, from its
# engines/*.py, are the egress allow-list below, so adding an engine means adding
# its hosts there. Upstream ships google `disabled` and mojeek and startpage
# `inactive` (never loaded, which `keep_only` alone does not undo), so each is
# switched on below.
#   google, duckduckgo, mojeek        general web results, three independent indexes
#   startpage                         Google's results through Startpage's proxy;
#                                     solves its Anubis proof-of-work (difficulty 4,
#                                     ~65k sha256, token cached 240s), which upstream
#                                     leaves off as a public-instance CPU precaution
#   wikipedia                         reference pages (English only: one host)
#   github, stackoverflow             code and Q&A, moved into `general` so a plain
#                                     query reaches them; API clients send no categories
# Not kept: brave (search.brave.com answers this address 429 even to a plain
# request, measured from the pod), qwant, and bing: it answers this address 200 with
# results unrelated to the query (an amdgpu query returned zip-code trivia and news
# sites, measured from the pod 2026-11-08), which SearXNG cannot tell from real ones
# and ranks into every answer. A refusal would at least be reported. google stays on while it is broken
# upstream (searxng#6835: /wml/search answers 403); suspended, it costs one
# request a day and returns on its own with the fix.
#
# Limiter off and no Valkey: every path in is private and admitted by the policies
# below, and the API clients are the fleet's own. SearXNG's limiter is a bot screen for
# inbound abuse; it does not pace OUR bursts toward the engines.
#
# OUTBOUND PACING, searxng-limit (an nginx in front, owner-approved 2026-11-09). Every
# query from every agent leaves through one residential address, and the engines judge
# that address by its burst rate: a fleet of agents searching at once earns CAPTCHAs and
# denials (measured: DuckDuckGo, Mojeek and Startpage returned CAPTCHA pages after bursts).
# So the internal LoadBalancer and the public route both reach nginx, not SearXNG:
#   · /search answers repeat for 10 min from a cache, and a cache hit is never paced;
#   · a miss is paced to one request per 2 s, with up to 4 queued (worst wait 8 s, under
#     genie tier 1's 15 s search timeout), and anything beyond is 429 at once;
#   · every other path passes through unpaced.
# The rate is a starting point: loosen it when the engines tolerate more.
# An engine that answered CAPTCHA or denial is suspended 10 min (suspended_times below),
# not upstream's day: paced traffic should not stay locked out on one bad burst.
#
# EGRESS: DNS through Cilium's DNS proxy (toFQDNs learns IPs only from lookups that
# pass it, as in genie-eval.nix), then the engine hosts on 443.
{
  den.aspects.kubernetes.services.ai.searxng =
    let
      namespace = "search";
      name = "searxng";
      port = 8080;
      serviceDomains = [ "search" ];

      engines = [
        "google"
        "duckduckgo"
        "mojeek"
        "startpage"
        "wikipedia"
        "github"
        "stackoverflow"
      ];

      engineHosts = [
        "duckduckgo.com"
        "html.duckduckgo.com"
        "lite.duckduckgo.com"
        "links.duckduckgo.com"
        "www.google.com"
        "www.mojeek.com"
        "www.startpage.com"
        "en.wikipedia.org"
        "api.github.com"
        "api.stackexchange.com"
      ];

      settingsFor = baseUrl: {
        use_default_settings.engines.keep_only = engines;
        general = {
          instance_name = "search";
          enable_metrics = false;
        };
        search = {
          formats = [
            "html"
            "json"
          ];
          autocomplete = "";
        };
        server = {
          base_url = baseUrl;
          limiter = false;
          public_instance = false;
          image_proxy = false;
        };
        search.suspended_times = {
          SearxEngineAccessDenied = 600;
          SearxEngineCaptcha = 600;
          SearxEngineTooManyRequests = 600;
          cf_SearxEngineCaptcha = 600;
          cf_SearxEngineAccessDenied = 600;
          recaptcha_SearxEngineCaptcha = 600;
        };
        engines = [
          {
            name = "google";
            disabled = false;
          }
          {
            name = "mojeek";
            inactive = false;
            disabled = false;
          }
          {
            name = "startpage";
            inactive = false;
            disabled = false;
          }
          {
            name = "wikipedia";
            language = "en";
          }
          {
            name = "github";
            categories = [
              "general"
              "it"
            ];
          }
          {
            name = "stackoverflow";
            categories = [
              "general"
              "it"
              "q&a"
            ];
          }
        ];
      };

      pod."app.kubernetes.io/name" = name;
      limitName = "${name}-limit";
      limitPod."app.kubernetes.io/name" = limitName;
      # Hits are served by the outer server from the cache and never reach the pacer; a
      # miss goes through the inner one, which holds the one global rate.
      limitConf = ''
        proxy_cache_path /var/cache/nginx/search levels=1:2 keys_zone=search:10m max_size=256m inactive=30m use_temp_path=off;
        map $host $engines { default all; }
        limit_req_zone $engines zone=engines:1m rate=30r/m;
        limit_req_status 429;
        upstream searxng { server ${name}.${namespace}.svc.cluster.local:${toString port}; }
        server {
          listen ${toString port};
          location = /search {
            proxy_cache search;
            proxy_cache_key $request_uri;
            proxy_cache_valid 200 10m;
            proxy_cache_lock on;
            proxy_cache_lock_timeout 15s;
            add_header X-Cache-Status $upstream_cache_status always;
            proxy_pass http://127.0.0.1:8081;
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
            proxy_read_timeout 30s;
          }
          location / {
            proxy_pass http://searxng;
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
          }
        }
        server {
          listen 127.0.0.1:8081;
          location / {
            limit_req zone=engines burst=4;
            proxy_pass http://searxng;
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-For $http_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
            proxy_read_timeout 30s;
          }
        }
      '';
      tcp = p: {
        port = toString p;
        protocol = "TCP";
      };
      ingressOn = peer: peer // { toPorts = [ { ports = [ (tcp port) ]; } ]; };
    in
    {
      service-domains = serviceDomains;
      served-domains = { cluster, ... }: cluster.servedDomains serviceDomains;

      age-secrets =
        { environment, ... }:
        {
          age.secrets = {
            searxng-secret-key = {
              rekeyFile = environment.secretPath + "/searxng/secret-key.age";
              generator.script = "hex";
              sopsOutput = {
                file = "searxng";
                key = "secret-key";
              };
            };
            # Shared with the kanidm client (services/security/kanidm.nix): same
            # rekeyFile, so one generated value backs both sides.
            searxng-oidc-client-secret = {
              rekeyFile = environment.secretPath + "/oidc/searxng-oidc-client-secret.age";
              generator = {
                tags = [ "oidc" ];
                script = "rfc3986-secret";
              };
              sopsOutput = {
                file = "oidc";
                key = "searxng";
              };
            };
          };
        };

      k8s-manifests =
        {
          cluster,
          charts,
          images,
          config,
          ...
        }:
        let
          host = cluster.domainFor "search";
        in
        {
          applications.${name} = {
            inherit namespace;

            helm.releases.${name} = {
              chart = charts.littleoffice.searxng;
              values = {
                # The chart cannot hash a settings Secret it does not write, so
                # editing that Secret would not roll the pod (SearXNG reads its
                # settings once, at boot). It is written here, so hash it here.
                commonAnnotations."checksum/settings" = builtins.hashString "sha256" (
                  builtins.toJSON (settingsFor "https://${host}/")
                );
                image = {
                  registry = "docker.io";
                  inherit (images."searxng/searxng") repository digest;
                  tag = "";
                };
                # A metasearch proxy holds no state; one replica until load says otherwise.
                replicaCount = 1;
                podDisruptionBudget.enabled = false;
                searxng = {
                  existingSecret = name;
                  existingSettingsSecret = name;
                  inherit port;
                  limiter.enabled = false;
                };
                service.port = port;
                valkey.enabled = false;
                # A `helm test` hook Pod; ArgoCD would apply it as a plain Pod.
                tests.enabled = false;
                # Cilium policies below instead: the chart's NetworkPolicies are
                # CIDR-only, and engine egress needs toFQDNs.
                networkPolicy.enabled = false;
              };
            };

            helm.releases.${limitName} = {
              chart = charts.bjw-s-labs.app-template;
              values = {
                controllers.main = {
                  type = "deployment";
                  containers.main = {
                    image = {
                      inherit (images."library/nginx") repository digest;
                    };
                    probes = {
                      liveness = {
                        enabled = true;
                        custom = true;
                        spec.tcpSocket.port = port;
                      };
                      readiness = {
                        enabled = true;
                        custom = true;
                        spec.tcpSocket.port = port;
                      };
                    };
                  };
                };
                service.main = {
                  controller = "main";
                  ports.http = { inherit port; };
                };
                configMaps.config.data."default.conf" = limitConf;
                persistence = {
                  config = {
                    type = "configMap";
                    identifier = "config";
                    globalMounts = [
                      {
                        path = "/etc/nginx/conf.d/default.conf";
                        subPath = "default.conf";
                        readOnly = true;
                      }
                    ];
                  };
                  # Regenerable: the cache dies with the pod.
                  cache = {
                    type = "emptyDir";
                    globalMounts = [ { path = "/var/cache/nginx"; } ];
                  };
                };
              };
            };

            resources = {
              secrets.${name}.stringData = {
                "settings.yml" = builtins.toJSON (settingsFor "https://${host}/");
                secret-key = config.age.secrets.searxng-secret-key.sopsRef;
              };

              services."${name}-internal" = {
                metadata.annotations."lbipam.cilium.io/ips" = cluster.getAssignment "searxng-internal";
                spec = {
                  type = "LoadBalancer";
                  externalTrafficPolicy = "Local";
                  selector = limitPod;
                  ports = [
                    {
                      name = "http";
                      inherit port;
                      targetPort = port;
                    }
                  ];
                };
              };

              httpRoutes.${name}.spec = {
                hostnames = [ host ];
                parentRefs = [
                  {
                    name = "default-gateway";
                    namespace = "gateways";
                    sectionName = "${cluster.domainForResource "search"}-https";
                  }
                ];
                rules = [
                  {
                    backendRefs = [
                      {
                        name = limitName;
                        inherit port;
                      }
                    ];
                  }
                ];
              };

              securityPolicies."${name}-oidc".spec = {
                targetRefs = [
                  {
                    group = "gateway.networking.k8s.io";
                    kind = "HTTPRoute";
                    inherit name;
                  }
                ];
                oidc = {
                  provider = cluster.secrets.oidcProviderFor name;
                  clientID = name;
                  clientSecret.name = "${name}-oidc-client-secret";
                  scopes = [
                    "email"
                    "openid"
                    "profile"
                  ];
                };
              };

              secrets."${name}-oidc-client-secret" = {
                type = "Opaque";
                stringData.client-secret = config.age.secrets.searxng-oidc-client-secret.sopsRef;
              };

              ciliumNetworkPolicies = {
                "${name}-ingress".spec = {
                  description = "searxng: its pacer (searxng-limit) only, on ${toString port}.";
                  endpointSelector.matchLabels = pod;
                  # Every query goes through the pacer, so no caller can burst the engines.
                  ingress = [ (ingressOn { fromEndpoints = [ { matchLabels = limitPod; } ]; }) ];
                };
                "${limitName}-ingress".spec = {
                  description = "searxng-limit: the gateway, genie tier 1 and private-LAN clients, on ${toString port} only.";
                  endpointSelector.matchLabels = limitPod;
                  ingress = [
                    (ingressOn {
                      fromEndpoints = [ { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; } ];
                    })
                    (ingressOn {
                      fromEndpoints = [
                        {
                          matchLabels = {
                            "k8s:io.kubernetes.pod.namespace" = "genie";
                            "k8s:io.cilium.k8s.policy.serviceaccount" = "genie-tier1";
                          };
                        }
                      ];
                    })
                    # Off-cluster callers over the internal LoadBalancer: the whole
                    # private 10/8, as allow-lan-ingress-hindsight reasons (portable;
                    # covers the caller's real IP under externalTrafficPolicy=Local
                    # and any node SNAT; the LB address is not internet-routable).
                    (ingressOn { fromCIDR = [ "10.0.0.0/8" ]; })
                  ];
                };
                "${limitName}-egress".spec = {
                  description = "searxng-limit: DNS, then searxng on ${toString port}.";
                  endpointSelector.matchLabels = limitPod;
                  egress = [
                    {
                      toEndpoints = [
                        {
                          matchLabels = {
                            "k8s:io.kubernetes.pod.namespace" = "kube-system";
                            "app.kubernetes.io/name" = "coredns";
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
                            (tcp 53)
                          ];
                        }
                      ];
                    }
                    {
                      toEndpoints = [ { matchLabels = pod; } ];
                      toPorts = [ { ports = [ (tcp port) ]; } ];
                    }
                  ];
                };

                "${name}-egress".spec = {
                  description = "searxng: DNS, then the engine hosts on 443.";
                  endpointSelector.matchLabels = pod;
                  egress = [
                    {
                      toEndpoints = [
                        {
                          # coredns.nix's own selector: the chart labels its pods
                          # k8s-app=coredns; only the Service carries kube-dns.
                          matchLabels = {
                            "k8s:io.kubernetes.pod.namespace" = "kube-system";
                            "app.kubernetes.io/name" = "coredns";
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
                            (tcp 53)
                          ];
                          rules.dns = [ { matchPattern = "*"; } ];
                        }
                      ];
                    }
                    {
                      toFQDNs = map (matchName: { inherit matchName; }) engineHosts;
                      toPorts = [ { ports = [ (tcp 443) ]; } ];
                    }
                  ];
                };
              };
            };
          };
        };
    };
}
