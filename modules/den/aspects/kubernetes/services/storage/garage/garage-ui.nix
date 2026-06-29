# Garage web UI (noooste/garage-ui) — the operator/bucket/key admin console.
# The chart's own auth (config.auth.oidc / config.auth.admin) is left DISABLED
# (values defaults): the UI serves unauthenticated and the Envoy Gateway kanidm
# OIDC SecurityPolicy below is the sole security boundary (spec §5.7). The UI
# drives the Garage admin API (3903) with the shared admin token (T3/T5).
#
# Chart surface pinned against garage-ui v0.8.4 (Step 3):
#   - admin endpoint  -> config.garage.admin_endpoint (NOT the plan's apiAdminUrl)
#   - admin token     -> env GARAGE_UI_GARAGE_ADMIN_TOKEN from
#                        config.garage.existingSecret.{name,key} (default key
#                        "admin-token"), satisfied by the garage-admin-token
#                        Secret (T3, key admin-token)
#   - Service         -> name "garage-ui" (release/fullname), port 80
#   - pod label       -> app.kubernetes.io/name = garage-ui (matches the T7 CNP
#                        selector — no reconciliation needed)
{
  den.aspects.kubernetes.services.storage.garage.garage-ui = {
    service-domains = [ "garage-ui" ];

    age-secrets =
      { environment, ... }:
      {
        # Shares its rekeyFile + generator with the kanidm garage-ui client's
        # basicSecretFile, so both sides resolve to the same value (the longhorn
        # idiom). The host-side age secret is auto-derived by kanidm.nix for every
        # non-public client; this declares the cluster (sops) half.
        age.secrets.garage-ui-oidc-client-secret = {
          rekeyFile = environment.secretPath + "/oidc/garage-ui-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          sopsOutput = {
            file = "oidc";
            key = "garage-ui";
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
        uiHost = cluster.domainFor "garage-ui";
      in
      {
        # Merges into the shared garage application (namespace anchored in
        # garage-cluster.nix). This aspect is the first to add a helm release to it.
        applications.garage = {
          helm.releases.garage-ui = {
            chart = charts.noooste.garage-ui;
            values = {
              config = {
                server = {
                  # Informational external URL (the chart only requires it for its
                  # own OIDC, which we leave off; set correctly for hygiene).
                  root_url = "https://${uiHost}";
                  domain = uiHost;
                };
                garage = {
                  endpoint = "http://garage.garage.svc:3900";
                  region = "garage";
                  # The operator's own `garage` Service exposes admin on :3903
                  # (no separate garage-admin Service — that collided with the operator).
                  admin_endpoint = "http://garage.garage.svc:3903";
                  # Admin bearer token from the agenix->sops garage-admin-token
                  # Secret (T3); chart injects it as GARAGE_UI_GARAGE_ADMIN_TOKEN.
                  existingSecret = {
                    name = "garage-admin-token";
                    key = "admin-token";
                  };
                };
              };
            };
          };

          resources = {
            # garage.json64.dev rides the existing *.json64.dev wildcard listener
            # (domainForResource "garage-ui" = json64-dev), so it attaches to the
            # existing json64-dev-https listener — no new cert.
            httpRoutes.garage-ui.spec = {
              hostnames = [ uiHost ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "garage-ui"}-https";
                }
              ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "garage-ui";
                      port = 80;
                    }
                  ];
                }
              ];
            };

            securityPolicies."garage-ui-oidc".spec = {
              targetRefs = [
                {
                  group = "gateway.networking.k8s.io";
                  kind = "HTTPRoute";
                  name = "garage-ui";
                }
              ];

              oidc = {
                provider.issuer = cluster.secrets.oidcIssuerFor "garage-ui";
                clientID = "garage-ui";
                clientSecret.name = "garage-ui-oidc-client-secret";
                scopes = [
                  "email"
                  "openid"
                  "profile"
                ];
                forwardAccessToken = true;
              };
            };

            secrets.garage-ui-oidc-client-secret = {
              type = "Opaque";
              stringData.client-secret = config.age.secrets.garage-ui-oidc-client-secret.sopsRef;
            };

            # garage-ui drives the Garage admin API only (3903). Once any egress
            # policy selects these pods they default-deny egress; DNS is covered by
            # the namespace-wide kube-dns egress policy in network-policy.nix (T7).
            ciliumNetworkPolicies.allow-garage-ui-admin-egress.spec = {
              description = "garage-ui to the Garage admin API (3903).";
              endpointSelector.matchLabels."app.kubernetes.io/name" = "garage-ui";
              egress = [
                {
                  toEndpoints = [
                    { matchLabels."app.kubernetes.io/name" = "garage"; }
                  ];
                  toPorts = [
                    {
                      ports = [
                        {
                          port = "3903";
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
}
