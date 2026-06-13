# Longhorn — distributed block storage via longhorn/longhorn Helm chart,
# 2-replica default, Retain policy, OIDC dashboard via Kanidm, HTTPRoute,
# CiliumNetworkPolicy.
{
  den.aspects.kubernetes.services.storage.longhorn = {
    service-domains = [ "longhorn" ];

    crds =
      { inputs, system, ... }:
      {
        name = "longhorn";
        chart = inputs.nixhelm.chartsDerivations.${system}.longhorn.longhorn;
        namePrefix = "longhorn";
      };

    age-secrets =
      { environment, ... }:
      {
        # Shares its rekeyFile AND generator with the kanidm OAuth2 client's
        # basicSecretFile, so both declarations resolve to the same value.
        age.secrets.longhorn-oidc-client-secret = {
          rekeyFile = environment.secretPath + "/oidc/longhorn-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          sopsOutput = {
            file = "oidc";
            key = "longhorn";
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
      {
        applications.longhorn = {
          namespace = "longhorn-system";

          syncPolicy = {
            syncOptions = {
              serverSideApply = true;
            };
          };

          compareOptions.serverSideDiff = true;

          helm.releases.longhorn = {
            chart = charts.longhorn.longhorn;
            values = {
              longhorn.preUpgradeChecker.jobEnabled = false;

              # Longhorn-manager metrics ServiceMonitor (grafana.com dashboard
              # 13032 imported in monitoring/grafana.nix charts on these).
              metrics.serviceMonitor.enabled = true;

              preUpgradeChecker.upgradeVersionCheck = false;

              defaultSettings = {
                createDefaultDiskLabeledNodes = true;
                defaultDataPath = "/var/lib/longhorn";
                backupstorePollInterval = 300;
                replicaSoftAntiAffinity = true;
                replicaAutoBalance = "best-effort";
              };

              persistence = {
                defaultClass = true;
                defaultClassReplicaCount = 2;
                reclaimPolicy = "Retain";
              };

              longhornUI.replicas = 1;
            };
          };

          resources = {
            httpRoutes.longhorn-dashboard.spec = {
              hostnames = [ (cluster.domainFor "longhorn") ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "longhorn"}-https";
                }
              ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "longhorn-frontend";
                      port = 80;
                    }
                  ];
                }
              ];
            };

            securityPolicies."longhorn-oidc".spec = {
              targetRefs = [
                {
                  group = "gateway.networking.k8s.io";
                  kind = "HTTPRoute";
                  name = "longhorn-dashboard";
                }
              ];

              oidc = {
                provider.issuer = cluster.secrets.oidcIssuerFor "longhorn";
                clientID = "longhorn";
                clientSecret.name = "longhorn-oidc-client-secret";
                scopes = [
                  "email"
                  "openid"
                  "profile"
                ];
                forwardAccessToken = true;
              };
            };

            secrets.longhorn-oidc-client-secret = {
              type = "Opaque";
              stringData.client-secret = config.age.secrets.longhorn-oidc-client-secret.sopsRef;
            };

            ciliumNetworkPolicies.allow-kube-apiserver-egress = {
              metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
              spec = {
                description = "Allow Longhorn pods to talk to kube-apiserver.";
                endpointSelector.matchLabels."k8s:io.kubernetes.pod.namespace" = "longhorn-system";
                egress = [
                  {
                    toEntities = [ "kube-apiserver" ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "443";
                            protocol = "TCP";
                          }
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
        };
      };
  };
}
