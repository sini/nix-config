{
  den,
  lib,
  config,
  ...
}:
{
  den.aspects.services.kanidm = {
    includes = [ den.aspects.services.nginx ];

    nixos =
      {
        config,
        host,
        pkgs,
        ...
      }:
      let
        env = config.den.environments.${host.environment};
        domain = env.getDomainFor "kanidm";
        topDomain = env.getTopDomainFor "kanidm";
      in
      {
        services = {
          kanidm = {
            package = pkgs.kanidm_1_9.withSecretProvisioning;

            server = {
              enable = true;
              settings = {
                inherit (env) domain;
                origin = "https://${domain}";
                bindaddress = "127.0.0.1:8443";
                ldapbindaddress = "127.0.0.1:3636";

                tls_chain = "${config.security.acme.certs.${topDomain}.directory}/fullchain.pem";
                tls_key = "${config.security.acme.certs.${topDomain}.directory}/key.pem";
              };
            };

            client = {
              enable = true;
              settings = {
                uri = "https://${domain}";
              };
            };

            provision = {
              enable = true;
              adminPasswordFile = config.age.secrets.kanidm-admin-password.path;
              idmAdminPasswordFile = config.age.secrets.kanidm-admin-password.path;
            };
          };

          nginx.virtualHosts."${domain}" = {
            forceSSL = true;
            useACMEHost = topDomain;
            locations."/" = {
              proxyPass = "https://127.0.0.1:8443";
              proxyWebsockets = true;
              extraConfig = ''
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;

                proxy_ssl_server_name on;
                proxy_ssl_name $host;
                proxy_ssl_verify_depth 2;
                proxy_ssl_protocols  TLSv1 TLSv1.1 TLSv1.2;
                proxy_ssl_session_reuse off;
              '';
            };
          };
        };

        # Ensure kanidm user can read secret files and certificates
        systemd.services.kanidm.serviceConfig = {
          SupplementaryGroups = [ "keys" ];
        };

        users.users.kanidm.extraGroups = [
          config.security.acme.defaults.group
          config.services.nginx.group
        ];
      };

    age-secrets =
      { host, ... }:
      let
        env = config.den.environments.${host.environment};
      in
      {
        age.secrets.kanidm-admin-password = {
          rekeyFile = env.secretPath + "/kanidm-admin-password.age";
          generator.script = "passphrase";
          owner = "kanidm";
          group = "kanidm";
        };
      };

    firewall = {
      networking.firewall.allowedTCPPorts = [ 3636 ];
    };

    service-domains = [ "kanidm" ];

    persist = {
      directories = [
        {
          directory = "/var/lib/kanidm";
          user = "kanidm";
          group = "kanidm";
          mode = "0700";
        }
      ];
    };
  };
}
