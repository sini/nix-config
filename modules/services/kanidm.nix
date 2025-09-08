{ rootPath, ... }:
{
  flake.modules.nixos.kanidm =
    { config, pkgs, ... }:
    {
      age.secrets.kanidm-admin-password = {
        rekeyFile = rootPath + "/.secrets/services/kanidm-admin-password.age";
        owner = "kanidm";
        group = "kanidm";
      };

      services = {
        kanidm = {
          enableServer = true;
          enableClient = true;
          package = pkgs.kanidm_1_7.withSecretProvisioning;

          serverSettings = {
            domain = config.networking.domain;
            origin = "https://auth.${config.networking.domain}";
            bindaddress = "127.0.0.1:8443";
            ldapbindaddress = "127.0.0.1:3636";
            trust_x_forward_for = true;

            # TLS certificates from ACME
            tls_chain = "${config.security.acme.certs.${config.networking.domain}.directory}/fullchain.pem";
            tls_key = "${config.security.acme.certs.${config.networking.domain}.directory}/key.pem";
          };

          clientSettings = {
            uri = "https://auth.${config.networking.domain}";
          };

          provision = {
            enable = true;
            adminPasswordFile = config.age.secrets.kanidm-admin-password.path;
            idmAdminPasswordFile = config.age.secrets.kanidm-admin-password.path;
          };
        };

        nginx.virtualHosts = {
          "auth.${config.networking.domain}" = {
            forceSSL = true;
            useACMEHost = config.networking.domain;
            locations."/" = {
              proxyPass = "https://127.0.0.1:8443";
              proxyWebsockets = true;
              extraConfig = ''
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
                proxy_ssl_verify off;
              '';
            };
          };
        };
      };

      # Open firewall for LDAP
      networking.firewall.allowedTCPPorts = [ 3636 ];

      # Ensure kanidm user can read the password file and certificates
      systemd.services.kanidm.serviceConfig = {
        SupplementaryGroups = [ "keys" ];
      };

      # Grant kanidm access to certificates
      users.users.kanidm.extraGroups = [ config.security.acme.defaults.group ];
    };
}
