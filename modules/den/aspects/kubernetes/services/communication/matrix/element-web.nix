# element-web — the Element web client for json64.dev, at chat.json64.dev.
#
# Static files only: it logs in through MAS (mas.nix), which it finds from the
# homeserver's auth metadata and registers itself with dynamically. Its
# client_uri and redirect are both on chat.json64.dev, as MAS's registration
# policy requires.
{ lib, ... }:
let
  serviceDomains = [ "chat" ];
  namespace = "matrix";
  name = "element-web";
  # The image's nginx listens on ELEMENT_WEB_PORT; 80 needs root, 8080 does not.
  port = 8080;
  uid = 101; # the image's nginx user

  tcp = p: {
    port = toString p;
    protocol = "TCP";
  };
in
{
  den.aspects.kubernetes.services.communication.matrix.element-web = {
    service-domains = serviceDomains;
    served-domains = { cluster, ... }: cluster.servedDomains serviceDomains;

    k8s-manifests =
      {
        cluster,
        charts,
        images,
        ...
      }:
      let
        homeserver = cluster.domainFor "matrix";
        elementConfig = {
          default_server_config."m.homeserver" = {
            base_url = "https://${homeserver}";
            server_name = "json64.dev";
          };
          disable_custom_urls = true;
          disable_guests = true;
          brand = "Element";
          default_theme = "dark";
          room_directory.servers = [ "json64.dev" ];
        };
      in
      {
        applications.${name} = {
          inherit namespace;

          helm.releases.${name} = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              defaultPodOptions.securityContext = {
                runAsNonRoot = true;
                runAsUser = uid;
                runAsGroup = uid;
              };
              controllers.main = {
                type = "deployment";
                replicas = 1;
                pod.annotations."checksum/config" = builtins.hashString "sha256" (builtins.toJSON elementConfig);
                containers.main = {
                  image = {
                    inherit (images."element-hq/element-web") repository digest;
                  };
                  env.ELEMENT_WEB_PORT = toString port;
                  probes = lib.genAttrs [ "liveness" "readiness" ] (_: {
                    enabled = true;
                    custom = true;
                    spec.httpGet = {
                      path = "/version";
                      inherit port;
                    };
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
                    path = "/app/config.json";
                    subPath = "config.json";
                    readOnly = true;
                  }
                ];
              };
            };
          };

          resources = {
            configMaps."${name}-config".data."config.json" = builtins.toJSON elementConfig;

            httpRoutes.${name}.spec = {
              hostnames = [ (cluster.domainFor "chat") ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "chat"}-https";
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

            ciliumNetworkPolicies.allow-gateway-ingress-element-web.spec = {
              description = "Allow Envoy Gateway proxies to reach Element Web.";
              endpointSelector.matchLabels."app.kubernetes.io/name" = name;
              ingress = [
                {
                  fromEndpoints = [ { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; } ];
                  toPorts = [ { ports = [ (tcp port) ]; } ];
                }
              ];
            };
          };
        };
      };
  };
}
