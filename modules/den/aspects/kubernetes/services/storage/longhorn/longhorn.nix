# Longhorn — distributed block storage via longhorn/longhorn Helm chart,
# 2-replica default, Retain policy, OIDC dashboard via Kanidm, HTTPRoute,
# CiliumNetworkPolicy.
#
# Ported from main:modules/kubernetes/services/storage/longhorn/longhorn.nix
{
  lib,
  config,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    splitString
    take
    ;

  environments = config.den.environments;

  # Convert domain to k8s-safe resource name (last 2 parts, hyphenated)
  domainToResourceName =
    domain:
    let
      parts = splitString "." domain;
      topDomain = lib.reverseList (take 2 (lib.reverseList parts));
    in
    concatStringsSep "-" topDomain;
in
{
  den.aspects.kubernetes.services.storage.longhorn = {
    service-domains = [ "longhorn" ];

    crds =
      { inputs, system, ... }:
      {
        chart = inputs.nixhelm.chartsDerivations.${system}.longhorn.longhorn;
        namePrefix = "longhorn";
      };

    k8s-manifests =
      { cluster, charts, ... }:
      let
        environment = environments.${cluster.environment};
        longhornDomain = environment.getDomainFor "longhorn";
      in
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
              hostnames = [ longhornDomain ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${domainToResourceName longhornDomain}-https";
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
              stringData.client-secret = "\${sops:longhorn-oidc-client-secret}";
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
