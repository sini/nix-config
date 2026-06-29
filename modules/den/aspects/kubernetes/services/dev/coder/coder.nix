# Coder — self-hosted cloud development environments (control plane).
#
# The coderd server (Helm chart 2.34.4) is routed through the default gateway
# and authenticates against kanidm (OIDC client `coder`, same group-to-role ACL
# the kanidm host declares). State lives in the coder-pg CNPG cluster
# (coder-pg.nix); coderd consumes the composed DSN secret (coder-pg-dsn).
#
# Builds run on coderd's built-in provisioner daemons (external/separate
# provisioner daemons are a Coder Enterprise feature). The OIDC client secret is
# minted by agenix-rekey and surfaced as a SopsSecret.
#
# In-cluster egress (coder-pg, kube-dns) is covered by the clusterwide
# allow-internal-egress policy (cilium.nix); this aspect only needs to add the
# external world:443 egress for the server-side OIDC calls to kanidm.
{
  den.aspects.kubernetes.services.dev.coder.coder = {
    age-secrets =
      { environment, ... }:
      {
        age.secrets = {
          # The SAME .age file the kanidm host consumes for the coder OIDC
          # client (basicSecretFile in kanidm.nix) — both sides read one secret.
          coder-oidc-client-secret = {
            rekeyFile = environment.secretPath + "/oidc/coder-oidc-client-secret.age";
            generator = {
              tags = [ "oidc" ];
              script = "rfc3986-secret";
            };
            sopsOutput = {
              file = "oidc";
              key = "coder";
            };
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
        domain = cluster.domainFor "coder";
        kanidmDomain = cluster.domainFor "kanidm";
      in
      {
        applications.coder = {
          namespace = "coder";

          helm.releases.coder = {
            chart = charts.coder.coder;

            values.coder = {
              # Keep the PUBLIC access URL: the chart otherwise rewrites
              # CODER_ACCESS_URL to the in-cluster Service URL.
              envUseClusterAccessURL = false;

              # We author our own HTTPRoute (resources.httpRoutes below); the
              # chart's coder.httproute.enable defaults to false. The Service
              # backs the route in-cluster (chart default type is LoadBalancer).
              service.type = "ClusterIP";

              # env is a verbatim EnvVar list (chart toYaml's it through), so
              # valueFrom.secretKeyRef entries are honored.
              env = [
                {
                  name = "CODER_ACCESS_URL";
                  value = "https://${domain}";
                }
                # Full connection URL from the composed coder-pg-dsn secret (the
                # chart's coder-db-url pattern).
                {
                  name = "CODER_PG_CONNECTION_URL";
                  valueFrom.secretKeyRef = {
                    name = "coder-pg-dsn";
                    key = "url";
                  };
                }
                {
                  name = "CODER_OIDC_ISSUER_URL";
                  value = "https://${kanidmDomain}/oauth2/openid/coder";
                }
                {
                  name = "CODER_OIDC_CLIENT_ID";
                  value = "coder";
                }
                {
                  name = "CODER_OIDC_CLIENT_SECRET";
                  valueFrom.secretKeyRef = {
                    name = "coder-oidc-client-secret";
                    key = "client-secret";
                  };
                }
                {
                  name = "CODER_OIDC_SCOPES";
                  value = "openid,profile,email,groups";
                }
                {
                  name = "CODER_OIDC_USER_ROLE_FIELD";
                  value = "groups";
                }
                {
                  name = "CODER_OIDC_USER_ROLE_MAPPING";
                  value = builtins.toJSON { admin = [ "owner" ]; };
                }
                # kanidm OIDC is the only login path. Disabling password auth also
                # removes the first-run setup wizard — the first OIDC login (a
                # coder.admins member → owner) bootstraps the deployment. Also
                # disable Coder's built-in default GitHub login provider.
                {
                  name = "CODER_DISABLE_PASSWORD_AUTH";
                  value = "true";
                }
                {
                  name = "CODER_OAUTH2_GITHUB_DEFAULT_PROVIDER_ENABLE";
                  value = "false";
                }
                # Built-in provisioner daemons run inside the coderd process
                # (external provisioners are a Coder Enterprise feature).
                {
                  name = "CODER_PROVISIONER_DAEMONS";
                  value = "3";
                }
              ];
            };
          };

          resources = {
            httpRoutes.coder.spec = {
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "coder"}-https";
                }
              ];
              hostnames = [ (cluster.domainFor "coder") ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "coder";
                      port = 80;
                    }
                  ];
                }
              ];
            };

            secrets = {
              coder-oidc-client-secret = {
                type = "Opaque";
                stringData.client-secret = config.age.secrets.coder-oidc-client-secret.sopsRef;
              };
            };

            ciliumNetworkPolicies = {
              # OIDC token/userinfo calls go server-side from the coderd pod to
              # kanidm, which lives outside the cluster (world entity).
              allow-coder-kanidm-egress.spec = {
                description = "Allow coder to reach kanidm for OIDC token/userinfo calls.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "coder";
                egress = [
                  {
                    toEntities = [ "world" ];
                    toPorts = [
                      {
                        ports = [
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
            };
          };
        };
      };
  };
}
