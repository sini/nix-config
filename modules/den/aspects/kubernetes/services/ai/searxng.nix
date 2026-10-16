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
# serve a datacenter address and answer what the fleet asks. Each one's endpoints,
# from its engines/*.py, are the egress allow-list below, so adding an engine means
# adding its hosts there.
#   duckduckgo, brave, mojeek  general web results, three independent indexes
#   wikipedia                  reference pages (English only: one host)
#   github, stackoverflow      code and Q&A, moved into `general` so a plain
#                              query reaches them; API clients send no categories
# Not kept: google, bing, startpage, qwant (they block or captcha datacenter IPs
# within hours, and an engine that errors costs every query its timeout).
#
# Limiter off and no Valkey: every path in is private and admitted by the policies
# below, and the API clients are the fleet's own.
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
        "duckduckgo"
        "brave"
        "mojeek"
        "wikipedia"
        "github"
        "stackoverflow"
      ];

      engineHosts = [
        "duckduckgo.com"
        "html.duckduckgo.com"
        "lite.duckduckgo.com"
        "links.duckduckgo.com"
        "search.brave.com"
        "www.mojeek.com"
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
        engines = [
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
            createNamespace = true;

            helm.releases.${name} = {
              chart = charts.littleoffice.searxng;
              values = {
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
                  selector = pod;
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
                        inherit name port;
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
                  description = "searxng: the gateway, genie tier 1 and private-LAN clients, on ${toString port} only.";
                  endpointSelector.matchLabels = pod;
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
