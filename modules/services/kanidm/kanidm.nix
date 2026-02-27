{ rootPath, ... }:
{
  flake.features.kanidm.nixos =
    {
      config,
      pkgs,
      environment,
      ...
    }:
    {
      age.secrets.kanidm-admin-password = {
        rekeyFile = rootPath + "/.secrets/env/${environment.name}/kanidm-admin-password.age";
        owner = "kanidm";
        group = "kanidm";
      };

      services = {
        kanidm = {
          package = pkgs.kanidm_1_9.withSecretProvisioning;

          server = {
            enable = true;
            settings = {
              domain = environment.domain;
              origin = "https://idm.${environment.domain}";
              bindaddress = "127.0.0.1:8443";
              ldapbindaddress = "127.0.0.1:3636";

              # TLS certificates from ACME
              tls_chain = "${config.security.acme.certs.${environment.domain}.directory}/fullchain.pem";
              tls_key = "${config.security.acme.certs.${environment.domain}.directory}/key.pem";
            };
          };

          client = {
            enable = true;
            settings = {
              uri = "https://idm.${environment.domain}";
            };
          };

          provision = {
            enable = true;
            adminPasswordFile = config.age.secrets.kanidm-admin-password.path;
            idmAdminPasswordFile = config.age.secrets.kanidm-admin-password.path;
          };

        };

        nginx.virtualHosts."idm.${environment.domain}" = {
          forceSSL = true;
          useACMEHost = environment.domain;
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

      # Open firewall for LDAP
      networking.firewall.allowedTCPPorts = [ 3636 ];

      # Ensure kanidm user can read the secret files and certificates
      systemd.services.kanidm.serviceConfig = {
        SupplementaryGroups = [ "keys" ];
      };

      environment.persistence."/persist".directories = [
        {
          directory = "/var/lib/kanidm";
          user = "kanidm";
          group = "kanidm";
          mode = "0700";
        }
      ];

      # Grant kanidm access to certificates
      users.users.kanidm.extraGroups = [
        config.security.acme.defaults.group
        config.services.nginx.group
      ];
    };
}
