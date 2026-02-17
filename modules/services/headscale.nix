{ rootPath, ... }:
{
  flake.features.headscale.nixos =
    {
      config,
      environment,
      pkgs,
      ...
    }:
    {
      age.secrets.headscale-oidc-secret = {
        rekeyFile = rootPath + "/.secrets/env/${environment.name}/oidc/headscale-oidc-client-secret.age";
        mode = "440";
        owner = config.services.headscale.user;
        inherit (config.services.headscale) group;
      };

      services = {
        headscale = {
          enable = true;
          address = "0.0.0.0";
          port = 8085;

          settings = {
            server_url = "https://hs.${environment.domain}";
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
              base_domain = "ts.${environment.domain}";
              override_local_dns = true;
              nameservers.global = [
                "1.1.1.1"
                "1.0.0.1"
                "2606:4700:4700::1111"
                "2606:4700:4700::1001"
              ];
            };

            # OIDC authentication via kanidm.
            oidc = {
              only_start_if_oidc_is_available = true;
              issuer = "https://idm.${environment.domain}/oauth2/openid/headscale";
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

        nginx.virtualHosts."hs.${environment.domain}" = {
          forceSSL = true;
          useACMEHost = environment.domain;
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

      networking.firewall.allowedUDPPorts = [
        3478
        41641
      ];

      environment.systemPackages = [
        config.services.headscale.package
      ];

      environment.persistence."/persist".directories = [
        "/var/lib/headscale"
      ];
    };

}
