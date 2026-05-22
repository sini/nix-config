{
  den,
  lib,
  config,
  ...
}:
let
  environments = config.den.environments;
in
{
  den.aspects.services.headscale = {
    includes = [ den.aspects.services.nginx ];

    nixos =
      {
        config,
        host,
        pkgs,
        ...
      }:
      let
        env = environments.${host.environment};
        domain = env.getDomainFor "headscale";
        kanidmDomain = env.getDomainFor "kanidm";
      in
      {
        services = {
          headscale = {
            enable = true;
            address = "0.0.0.0";
            port = 8085;

            settings = {
              server_url = "https://${domain}";
              logtail = {
                enabled = false;
              };
              prefixes = {
                v4 = "100.72.0.0/16";
                v6 = "fd7a:115c:a1e0::/48";
                allocation = "random";
              };
              derp = {
                server = {
                  enabled = true;
                  region_id = 999;
                  region_code = config.networking.hostName;
                  region_name = config.networking.hostName + " DERP";
                  stun_listen_addr = "0.0.0.0:3478";
                  auto_update_enabled = true;
                  automatically_add_embedded_derp_region = true;
                };
              };

              metrics_listen_addr = "127.0.0.1:8090";

              dns = {
                magic_dns = true;
                base_domain = "ts.${env.domain}";
                override_local_dns = true;
                nameservers.global = [
                  "1.1.1.1"
                  "1.0.0.1"
                  "2606:4700:4700::1111"
                  "2606:4700:4700::1001"
                ];
              };

              oidc = {
                only_start_if_oidc_is_available = true;
                issuer = "https://${kanidmDomain}/oauth2/openid/headscale";
                client_id = "headscale";
                client_secret_path = config.age.secrets.headscale-oidc-secret.path;
                scope = [
                  "openid"
                  "profile"
                  "email"
                ];
                pkce = {
                  enabled = true;
                  method = "S256";
                };
              };

              policy.path = pkgs.writeText "policy.json" (
                builtins.toJSON {
                  acls = [
                    {
                      action = "accept";
                      src = [ "*" ];
                      dst = [ "*:*" ];
                    }
                  ];
                }
              );
            };
          };

          nginx.virtualHosts."${domain}" = {
            forceSSL = true;
            useACMEHost = env.getTopDomainFor "headscale";
            locations = {
              "/" = {
                proxyPass = "http://localhost:${toString config.services.headscale.port}";
                proxyWebsockets = true;
              };
              "/metrics" = {
                proxyPass = "http://${config.services.headscale.settings.metrics_listen_addr}/metrics";
              };
            };
          };
        };

        environment.systemPackages = [
          config.services.headscale.package
        ];
      };

    age-secrets =
      { host, ... }:
      let
        env = environments.${host.environment};
      in
      {
        age.secrets.headscale-oidc-secret = {
          rekeyFile = env.secretPath + "/oidc/headscale-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          mode = "440";
          owner = "headscale";
          group = "headscale";
        };
      };

    firewall = {
      networking.firewall.allowedUDPPorts = [
        3478
        41641
      ];
    };

    service-domains = [ "headscale" ];

    persist = {
      directories = [
        "/var/lib/headscale"
      ];
    };

    prometheus-targets = [
      {
        job_name = "headscale";
        port = 8090;
      }
    ];
  };
}
