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
      { cluster, environment, ... }:
      {
        # JWT signing key for the UI's own session cookies. Owned here rather
        # than left to the chart: garage-ui's secret template mints one with
        # `genPrivateKey "ed25519"` guarded by a `lookup` for an existing
        # Secret, and `lookup` always returns empty under `helm template` — which
        # is how nixidy renders. The guard therefore never fires here, so every
        # full nixidy-sync minted a NEW key and committed it, silently rotating
        # the live one and dropping every session. Cluster-scoped like the other
        # garage secrets: nothing host-side consumes it.
        age.secrets.garage-ui-jwt-key = {
          rekeyFile = cluster.secretPath + "/garage/ui-jwt-key.age";
          generator.script = "ed25519-private-key";
          sopsOutput = {
            file = "garage";
            key = "ui-jwt-key";
          };
        };

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
                # Point the chart at the Secret declared below. Setting this
                # name switches OFF both of the chart's jwt-key emit branches,
                # so the key is ours end to end and stable across renders.
                auth.jwt_private_key_secret = {
                  name = "garage-ui-jwt-key";
                  key = "jwt-key.pem";
                };
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

            secrets = {
              garage-ui-oidc-client-secret = {
                type = "Opaque";
                stringData.client-secret = config.age.secrets.garage-ui-oidc-client-secret.sopsRef;
              };

              # Same name the chart used, so the live Secret is replaced in
              # place rather than renamed. Its VALUE changes once on this
              # deploy (active UI sessions drop), then never again.
              garage-ui-jwt-key = {
                type = "Opaque";
                stringData."jwt-key.pem" = config.age.secrets.garage-ui-jwt-key.sopsRef;
              };
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
