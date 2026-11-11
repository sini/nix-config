# The resolver's admin panel (docs/dns-resolver.md §2.6): blocky-ui at
# dns.<domain> behind the gateway's kanidm OIDC SecurityPolicy, admins only (the
# garage-ui pattern: the kanidm client's scope map is the authorization). Its
# servers are the environment's resolver instances, from their dns-resolvers
# records' `api`; Blocky's API has no authentication, so the pod may reach those
# addresses on their API ports and nothing else (the cluster's own instance by
# its pods, docs/dns-resolver.md §2.7).
{ lib, ... }:
let
  serviceDomains = [ "dns" ];
  name = "blocky-ui";
  port = 3000;
  tcp = p: {
    port = toString p;
    protocol = "TCP";
  };
  # "http://10.10.10.1:4000" -> { ip = "10.10.10.1"; port = 4000; }
  apiOf =
    r:
    let
      m = lib.match "http://([0-9.]+):([0-9]+)/?" r.api;
    in
    if m == null then
      throw "blocky-ui: resolver ${r.name}'s api ${r.api} is not http://<ipv4>:<port>"
    else
      {
        ip = lib.elemAt m 0;
        port = lib.toInt (lib.elemAt m 1);
      };
in
{
  den.aspects.kubernetes.services.network.blocky-ui = {
    served-domains = { cluster, ... }: cluster.servedDomains serviceDomains;

    # Shares its rekeyFile + generator with the kanidm blocky-ui client's
    # basicSecretFile (auto-derived by kanidm.nix), so both sides hold one value.
    age-secrets =
      { environment, ... }:
      {
        age.secrets.blocky-ui-oidc-client-secret = {
          rekeyFile = environment.secretPath + "/oidc/blocky-ui-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          sopsOutput = {
            file = "oidc";
            key = "blocky-ui";
          };
        };
      };

    k8s-manifests =
      {
        config,
        cluster,
        charts,
        images,
        dns-resolvers,
        ...
      }:
      let
        host = cluster.domainFor "dns";
        resolvers = lib.throwIf (
          inEnv == [ ]
        ) "blocky-ui: no dns-resolvers record in ${cluster.environment}" inEnv;
        inEnv = lib.filter (r: r.environment == cluster.environment) dns-resolvers;
        uiConfig = {
          servers = lib.listToAttrs (
            map (
              r:
              lib.nameValuePair r.name {
                inherit (r) name;
                url = r.api;
              }
            ) resolvers
          );
          instanceName = "${cluster.environment} DNS";
        };
      in
      {
        applications.${name} = {
          helm.releases.${name} = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              # The image's `nextjs` user (1001:65533 in its /etc/passwd); named, so
              # runAsNonRoot needs the numbers.
              defaultPodOptions.securityContext = {
                runAsNonRoot = true;
                runAsUser = 1001;
                runAsGroup = 65533;
              };
              controllers.main = {
                type = "deployment";
                replicas = 1;
                pod.annotations."checksum/config" = builtins.hashString "sha256" (builtins.toJSON uiConfig);
                containers.main = {
                  image = {
                    inherit (images."gabeduartem/blocky-ui") repository digest;
                  };
                  env = {
                    BLOCKY_UI_CONFIG = "/config/blocky-ui.yml";
                    # The kubelet sets HOSTNAME to the pod name, which Next.js would bind.
                    HOSTNAME = "0.0.0.0";
                    PORT = toString port;
                  };
                  securityContext = {
                    allowPrivilegeEscalation = false;
                    capabilities.drop = [ "ALL" ];
                  };
                  probes = lib.genAttrs [ "liveness" "readiness" ] (_: {
                    enabled = true;
                    custom = true;
                    spec.tcpSocket = { inherit port; };
                  });
                };
              };
              service.main = {
                controller = "main";
                ports.http.port = port;
              };
              persistence.config = {
                type = "configMap";
                name = "${name}-config";
                globalMounts = [
                  {
                    path = "/config/blocky-ui.yml";
                    subPath = "blocky-ui.yml";
                    readOnly = true;
                  }
                ];
              };
            };
          };

          resources = {
            # JSON is YAML.
            configMaps."${name}-config".data."blocky-ui.yml" = builtins.toJSON uiConfig;

            httpRoutes.${name}.spec = {
              hostnames = [ host ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "dns"}-https";
                }
              ];
              rules = [ { backendRefs = [ { inherit name port; } ]; } ];
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
                forwardAccessToken = true;
              };
            };

            secrets."${name}-oidc-client-secret" = {
              type = "Opaque";
              stringData.client-secret = config.age.secrets.blocky-ui-oidc-client-secret.sopsRef;
            };

            # In from the gateway proxies only; out to each resolver's API only (DNS
            # comes from coredns.nix's cluster-wide grant).
            ciliumNetworkPolicies = {
              allow-gateway-ingress-blocky-ui.spec = {
                description = "Allow Envoy Gateway proxies to reach blocky-ui.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = name;
                ingress = [
                  {
                    fromEndpoints = [ { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; } ];
                    toPorts = [ { ports = [ (tcp port) ]; } ];
                  }
                ];
              };
              allow-blocky-ui-api-egress.spec = {
                description = "blocky-ui to the resolvers' Blocky API.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = name;
                egress = map (
                  r:
                  let
                    a = apiOf r;
                  in
                  # This cluster's own instance: its LB address is translated to the
                  # blocky pods before policy applies, so the rule names the pods.
                  (
                    if r.name == cluster.name then
                      {
                        toEndpoints = [
                          {
                            matchLabels = {
                              "k8s:io.kubernetes.pod.namespace" = "blocky";
                              "app.kubernetes.io/name" = "blocky";
                            };
                          }
                        ];
                      }
                    else
                      { toCIDR = [ "${a.ip}/32" ]; }
                  )
                  // {
                    toPorts = [ { ports = [ (tcp a.port) ]; } ];
                  }
                ) resolvers;
              };
            };
          };
        };
      };
  };
}
