{
  den.aspects.services.storage.minio = {
    nixos =
      {
        config,
        environment,
        host,
        ...
      }:
      let
        minioDomain = environment.getDomainFor "minio";
        minioConsoleDomain = environment.getDomainFor "minio-console";
      in
      {
        services = {
          minio = {
            enable = true;
            listenAddress = "127.0.0.1:9000";
            consoleAddress = "127.0.0.1:9001";
            dataDir = [ "/var/lib/minio/data" ];
            rootCredentialsFile = config.age.secrets.minio-root-credentials.path;
          };

          nginx.virtualHosts = {
            "${minioDomain}" = {
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

            "${minioConsoleDomain}" = {
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

        systemd.tmpfiles.rules = [
          "d /var/lib/minio 0755 minio minio -"
          "d /var/lib/minio/data 0755 minio minio -"
        ];

        systemd.services.minio.serviceConfig = {
          SupplementaryGroups = [ "keys" ];
        };
      };

    age-secrets =
      { environment, host, ... }:
      {
        age.secrets.minio-root-credentials = {
          rekeyFile = environment.secretPath + "/oidc/minio-root-credentials.age";
          owner = "minio";
          group = "minio";
        };
      };

    service-domains = [
      "minio"
      "minio-console"
    ];

    firewall = {
      networking.firewall.allowedTCPPorts = [
        9000
        9001
      ];
    };

    persist = {
      directories = [
        {
          directory = "/var/lib/minio";
          user = "minio";
          group = "minio";
          mode = "0755";
        }
      ];
    };
  };
}
