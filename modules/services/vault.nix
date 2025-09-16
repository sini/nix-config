{
  flake.modules.nixos.vault =
    { config, ... }:
    {
      services = {
        vault = {
          enable = true;
          address = "127.0.0.1:8200";
          storageBackend = "file";
          storageConfig = ''
            path = "/var/lib/vault/data"
          '';
          extraConfig = ''
            ui = true

            listener "tcp" {
              address = "127.0.0.1:8200"
              tls_disable = true
            }

            api_addr = "https://vault.${config.networking.domain}"
            cluster_addr = "https://vault.${config.networking.domain}:8201"

            log_level = "Info"
            log_format = "json"

            seal "transit" {
              address = "https://vault.${config.networking.domain}"
              disable_renewal = "false"
              key_name = "autounseal"
              mount_path = "transit/"
              tls_skip_verify = "false"
            }
          '';
        };

        nginx.virtualHosts."vault.${config.networking.domain}" = {
          forceSSL = true;
          useACMEHost = config.networking.domain;
          locations."/" = {
            proxyPass = "http://127.0.0.1:8200";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
              proxy_set_header X-Forwarded-Port $server_port;
            '';
          };
        };
      };

      # Open firewall for Vault API
      networking.firewall.allowedTCPPorts = [
        8200
        8201
      ];

      # Ensure Vault data directory exists with proper permissions
      systemd.tmpfiles.rules = [
        "d /var/lib/vault 0700 vault vault -"
        "d /var/lib/vault/data 0700 vault vault -"
      ];

      # Add vault user to keys group for secret access
      users.users.vault.extraGroups = [ "keys" ];
    };
}
