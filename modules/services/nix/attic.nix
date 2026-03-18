{ rootPath, ... }:
{
  flake.features.attic-server.linux =
    {
      host,
      config,
      environment,
      pkgs,
      ...
    }:
    let
      zfsEnabled = host.hasFeature "zfs-root";
      domain = environment.getDomainFor "attic";
    in
    {
      age.secrets.attic-server-token = {
        rekeyFile = rootPath + "/.secrets/services/attic/server-token.age";
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

      age.secrets.attic-server-env = {
        generator.dependencies = [ config.age.secrets.attic-server-token ];
        settings.keys = [ "ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64" ];
        generator.script = "environment-file";
      };

      environment.systemPackages = [ pkgs.attic-client ];

      services = {
        atticd = {
          enable = true;

          environmentFile = config.age.secrets.attic-server-env.path;

          settings = {
            listen = "[::1]:57448";

            allowed-hosts = [ domain ];
            api-endpoint = "https://${domain}/";

            # storage = {
            #   type = "local";
            #   path = "/var/lib/atticd/storage";
            # };

            # Compression is provided by ZFS
            # compression.type = "zstd";
            compression.type = if zfsEnabled then "none" else "zstd";

            # Chunking parameters (defaults are excellent for deduplication)
            chunking = {
              nar-size-threshold = 64 * 1024; # 64 KiB
              min-size = 16 * 1024; # 16 KiB
              avg-size = 64 * 1024; # 64 KiB
              max-size = 256 * 1024; # 256 KiB
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
            useACMEHost = environment.getTopDomainFor "attic";
            locations."/" = {
              proxyPass = "http://[::1]:57448";
              extraConfig = ''
                client_max_body_size 4G;
              '';
            };
          };
        };
      };

      environment.persistence."/cache".directories = [
        {
          # NOTE: systemd Dynamic User requires /var/lib/private to be 0700. See impermanence module
          directory = "/var/lib/private/atticd";
          user = "nobody";
          group = "nogroup";
          mode = "0700";
        }
      ];
    };
}
