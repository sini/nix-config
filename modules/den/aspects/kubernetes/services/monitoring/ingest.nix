# Monitoring ingest — the cluster's write endpoint for everything outside it.
#
# Hosts push (Alloy) instead of the cluster scraping them, so hosts need no
# inbound rules and hosts the cluster cannot dial still report. An nginx
# proxy on a private LoadBalancer terminates TLS (ingest.<domain>), checks
# basic auth, and forwards exactly two requests:
#   POST /api/v1/write       -> Prometheus remote-write
#   POST /loki/api/v1/push   -> Loki push
# Everything else is 404: Prometheus serves its query and admin (delete) APIs
# on the same port, and none of that leaves the cluster.
#
# The password (ingest-password) is shared with the hosts' Alloy via the same
# rekeyFile; the proxy only holds its bcrypt htpasswd.
let
  name = "monitoring-ingest";
  user = "ingest";
in
{
  den.aspects.kubernetes.services.monitoring.ingest = {
    age-secrets =
      { config, environment, ... }:
      {
        age.secrets = {
          monitoring-ingest-password = {
            rekeyFile = environment.secretPath + "/monitoring/ingest-password.age";
            generator.script = "passphrase";
          };
          monitoring-ingest-htpasswd = {
            rekeyFile = environment.secretPath + "/monitoring/ingest-htpasswd.age";
            generator = {
              script = "htpasswd";
              dependencies = [ config.age.secrets.monitoring-ingest-password ];
            };
            settings.username = user;
            sopsOutput = {
              file = "monitoring";
              key = "ingest-htpasswd";
            };
          };
        };
      };

    k8s-manifests =
      {
        config,
        cluster,
        charts,
        environment,
        images,
        ...
      }:
      let
        hostname = "ingest.${environment.domain}";
        upstream = svc: port: "http://${svc}.monitoring.svc.cluster.local:${toString port}";
        writeOnly = path: target: ''
          location = ${path} {
            limit_except POST { deny all; }
            auth_basic "monitoring ingest";
            auth_basic_user_file /auth/htpasswd;
            client_max_body_size 32m;
            proxy_pass ${target};
          }
        '';
        nginxConf = ''
          server {
            listen 8443 ssl;
            server_name ${hostname};
            ssl_certificate /tls/tls.crt;
            ssl_certificate_key /tls/tls.key;

            ${writeOnly "/api/v1/write" "${upstream "kube-prometheus-stack-prometheus" 9090}/api/v1/write"}
            ${writeOnly "/loki/api/v1/push" "${upstream "loki" 3100}/loki/api/v1/push"}
            location / { return 404; }
          }
        '';
        port = 443;
      in
      {
        applications.${name} = {
          namespace = "monitoring";

          helm.releases.${name} = {
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
                      spec.tcpSocket.port = 8443;
                    };
                    readiness = {
                      enabled = true;
                      custom = true;
                      spec.tcpSocket.port = 8443;
                    };
                  };
                };
              };

              service.main = {
                controller = "main";
                type = "LoadBalancer";
                # Keep the client address, for the CIDR rule below.
                externalTrafficPolicy = "Local";
                annotations."lbipam.cilium.io/ips" = cluster.getAssignment name;
                ports.https = {
                  inherit port;
                  targetPort = 8443;
                };
              };

              configMaps.config.data."default.conf" = nginxConf;

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
                auth = {
                  type = "secret";
                  name = "${name}-htpasswd";
                  globalMounts = [
                    {
                      path = "/auth";
                      readOnly = true;
                    }
                  ];
                };
                tls = {
                  type = "secret";
                  name = "${name}-tls";
                  globalMounts = [
                    {
                      path = "/tls";
                      readOnly = true;
                    }
                  ];
                };
              };
            };
          };

          resources = {
            secrets."${name}-htpasswd".stringData.htpasswd =
              config.age.secrets.monitoring-ingest-htpasswd.sopsRef;

            certificates.${name}.spec = {
              secretName = "${name}-tls";
              issuerRef = {
                name = "${cluster.resourceForDomain hostname}-issuer";
                kind = "ClusterIssuer";
              };
              dnsNames = [ hostname ];
            };

            ciliumNetworkPolicies.allow-ingest-from-lan.spec = {
              description = "Allow LAN and tailnet hosts to push to the monitoring ingest proxy.";
              endpointSelector.matchLabels."app.kubernetes.io/name" = name;
              ingress = [
                {
                  fromCIDR = [
                    "10.0.0.0/8"
                    "100.64.0.0/10"
                  ];
                  toPorts = [
                    {
                      ports = [
                        {
                          port = "8443";
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
