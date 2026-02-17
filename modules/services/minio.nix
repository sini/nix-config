{ rootPath, ... }:
{
  flake.features.minio.nixos =
    { config, environment, ... }:
    {
      age.secrets.minio-root-credentials = {
        rekeyFile = rootPath + "/.secrets/env/${environment.name}/oidc/minio-root-credentials.age";
        owner = "minio";
        group = "minio";
      };

      services = {
        minio = {
          enable = true;
          listenAddress = "127.0.0.1:9000";
          consoleAddress = "127.0.0.1:9001";
          dataDir = [ "/var/lib/minio/data" ];
          rootCredentialsFile = config.age.secrets.minio-root-credentials.path;
        };

        nginx.virtualHosts = {
          "minio.${environment.domain}" = {
            forceSSL = true;
            useACMEHost = environment.domain;
            locations."/" = {
              proxyPass = "http://127.0.0.1:9000";
              proxyWebsockets = true;
              extraConfig = ''
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
                client_max_body_size 0;
              '';
            };
          };

          "minio-console.${environment.domain}" = {
            forceSSL = true;
            useACMEHost = environment.domain;
            locations."/" = {
              proxyPass = "http://127.0.0.1:9001";
              proxyWebsockets = true;
              extraConfig = ''
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
              '';
            };
          };
        };
      };

      # Open firewall for MinIO API and console
      networking.firewall.allowedTCPPorts = [
        9000
        9001
      ];

      # Ensure MinIO data directory exists with proper permissions
      systemd.tmpfiles.rules = [
        "d /var/lib/minio 0755 minio minio -"
        "d /var/lib/minio/data 0755 minio minio -"
      ];

      # Ensure minio service can read the credentials file
      systemd.services.minio.serviceConfig = {
        SupplementaryGroups = [ "keys" ];
      };
    };
}
