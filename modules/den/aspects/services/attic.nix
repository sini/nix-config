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
  den.aspects.services.attic = {
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
        domain = env.getDomainFor "attic";
        zfsEnabled = builtins.elem "zfs-root" (host.aspects or [ ]);
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
              useACMEHost = env.domain;
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
      { host, ... }:
      let
        env = environments.${host.environment};
      in
      {
        age.secrets = {
          attic-server-token = {
            rekeyFile = env.secretPath + "/attic/server-token.age";
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

    persist = {
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
