# atticd on uplink: the fleet's binary cache, at attic.<domain>.
#
# The `ci` cache is CI's: public-read, so GitHub runners and fleet hosts pull
# without a token, and pushed to only with `attic-ci-push-token` (push+pull on
# `ci`, nothing else). attic-ci-cache.service creates and configures it on boot
# from a token it mints for itself; the server keeps no declarative cache list.
# Its public key, printed by that unit, is the one core/nix/nix.nix trusts.
#
# Uploads of CI size: the name is grey in Cloudflare (proxied mode caps a request
# at 100 MB), and nginx streams the body to atticd rather than buffering it, with
# the registry vhost's 900s timeouts, since atticd chunks a NAR before it answers.
{ den, lib, ... }:
let
  serviceDomains = [ "attic" ];
  ciCache = "ci";
  # atticadm signs tokens with the server's RS256 secret and reads it from this
  # config; it needs no running server.
  atticadmFor =
    pkgs: settings:
    "${pkgs.attic-server}/bin/atticadm -f ${(pkgs.formats.toml { }).generate "server.toml" settings}";
in
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

        # Creates `ci` if absent and keeps it public, idempotently, from a
        # ten-minute token scoped to that one cache.
        systemd.services.attic-ci-cache = {
          description = "Ensure the attic `${ciCache}` cache exists and is public";
          after = [ "atticd.service" ];
          requires = [ "atticd.service" ];
          wantedBy = [ "multi-user.target" ];
          path = [ pkgs.attic-client ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            DynamicUser = true;
            EnvironmentFile = config.age.secrets.attic-server-env.path;
            Restart = "on-failure";
            RestartSec = 10;
          };
          script = ''
            export XDG_CONFIG_HOME=$(mktemp -d)
            token=$(${atticadmFor pkgs config.services.atticd.settings} make-token \
              --sub attic-ci-cache --validity 10m \
              --pull ${ciCache} --push ${ciCache} --create-cache ${ciCache} --configure-cache ${ciCache})
            attic login local http://${config.services.atticd.settings.listen} "$token" >/dev/null
            attic cache info local:${ciCache} >/dev/null 2>&1 || attic cache create --public local:${ciCache}
            attic cache configure --public local:${ciCache}
            attic cache info local:${ciCache}
          '';
        };

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
                  proxy_request_buffering off;
                  proxy_read_timeout 900s;
                  proxy_send_timeout 900s;
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

          # CI's token: push+pull on `ci` only, five years. Never deployed to a host;
          # the github terranix workspace sets it as each repo's ATTIC_TOKEN at
          # apply time. Rotate by deleting the .age and running `agenix generate`.
          attic-ci-push-token = {
            rekeyFile = environment.secretPath + "/attic/ci-push-token.age";
            intermediary = true;
            generator = {
              tags = [ "attic" ];
              dependencies = [ config.age.secrets.attic-server-token ];
              script =
                {
                  decrypt,
                  deps,
                  pkgs,
                  ...
                }:
                ''
                  ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64=$(${decrypt} ${lib.escapeShellArg (lib.head deps).file}) \
                    ${atticadmFor pkgs config.services.atticd.settings} make-token \
                    --sub github-actions --validity 5y --pull ${ciCache} --push ${ciCache}
                '';
            };
          };
        };
      };

    service-domains = serviceDomains;
    served-domains =
      { environment, host, ... }:
      environment.servedDomains host {
        services = serviceDomains;
        proxied = false;
      };

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
