{ den, ... }:
{
  den.aspects.services.nix.attic = {
    includes = [ den.aspects.services.networking.nginx ];

    nixos =
      {
        config,
        environment,
        host,
        pkgs,
        ...
      }:
      let
        domain = environment.getDomainFor "attic";
        zfsEnabled = config.boot.supportedFilesystems.zfs or false;
      in
      {
        environment.systemPackages = [ pkgs.attic-client ];

        services = {
          atticd = {
            enable = true;

            environmentFile = config.age.secrets.attic-server-env.path;

            settings = {
              listen = "[::1]:57448";

              allowed-hosts = [ domain ];
              api-endpoint = "https://${domain}/";

              compression.type = if zfsEnabled then "none" else "zstd";

              chunking = {
                nar-size-threshold = 64 * 1024;
                min-size = 16 * 1024;
                avg-size = 64 * 1024;
                max-size = 256 * 1024;
              };

              garbage-collection = {
                interval = "12 hours";
                default-retention-period = "90 days";
              };
            };
          };

          nginx.virtualHosts = {
            "${domain}" = {
              forceSSL = true;
              useACMEHost = environment.domain;
              locations."/" = {
                proxyPass = "http://[::1]:57448";
                extraConfig = ''
                  client_max_body_size 4G;
                '';
              };
            };
          };
        };
      };

    age-secrets =
      {
        environment,
        host,
        config,
        ...
      }:
      {
        age.secrets = {
          attic-server-token = {
            rekeyFile = environment.secretPath + "/attic/server-token.age";
            intermediary = true;
            generator = {
              tags = [ "attic" ];
              script =
                { pkgs, ... }:
                ''
                  ${pkgs.openssl}/bin/openssl genrsa -traditional 4096 | base64 -w0
                '';
            };
          };

          attic-server-env = {
            generator.dependencies = [ config.age.secrets.attic-server-token ];
            settings.keys = [ "ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64" ];
            generator.script = "environment-file";
          };
        };
      };

    service-domains = [ "attic" ];

    cache = {
      directories = [
        {
          directory = "/var/lib/private/atticd";
          user = "nobody";
          group = "nogroup";
          mode = "0700";
        }
      ];
    };
  };
}
