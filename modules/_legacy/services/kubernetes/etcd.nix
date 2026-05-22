# {
#   features.etcd.linux =
#     { pkgs, ... }:
#     {
#       age.secrets.kubernetes-ca-crt = {
#         rekeyFile = rootPath + "/.secrets/env/${environment.name}/oidc/${name}-oidc-client-secret.age";
#         generator = {
#           tags = [ "kube" ];
#           runtimeInputs = [ pkgs.step-cli ];
#           dependencies = {
#             atticToken = config.age.secrets."universe/attic/token";
#             githubUsername = config.age.secrets."universe/github/username";
#             githubPassword = config.age.secrets."universe/github/password";
#           };
#           script =
#             { pkgs, ... }:
#             ''
#               # Generate an rfc3986 secret
#               secret=$(${pkgs.openssl}/bin/openssl rand -base64 54 | tr -d '\n' | tr '+/' '-_' | tr -d '=' | cut -c1-72)
#               echo "$secret"
#             '';
#         };
#       };

#       age.secrets.qui-secret = {
#         rekeyFile = ../../secrets/qui-secret.age;
#         generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 32";
#       };

#       # arrSecrets = name: {
#       #   "${name}Key".rekeyFile = ../../secrets/arrs/${name}Key.age;
#       #   "${name}Env" = {
#       #     generator = {
#       #       dependencies = [ config.age.secrets."${name}Key" ];
#       #       tags = [ "arrs" ];
#       #       script =
#       #         {
#       #           lib,
#       #           decrypt,
#       #           deps,
#       #           ...
#       #         }:
#       #         let
#       #           dep = lib.head deps;
#       #         in
#       #         ''
#       #           echo "${lib.strings.toUpper name}__AUTH__APIKEY=$(${decrypt} ${lib.escapeShellArg dep.file})"
#       #         '';
#       #     };
#       #   };
#       # };

#       #       age.secrets = mkMerge (flip mapAttrsToList config.glyph.restic (repo-name: _: {
#       #   "restic_auth_${repo-name}" = {
#       #     rekeyFile = ../../secrets/sources/restic/repo_auth_${repo-name}.age;
#       #     owner = "restic";
#       #     generator = {
#       #       script = { lib, pkgs, decrypt, deps, ... }: ''
#       #         printf 'RESTIC_REST_USERNAME="${repo-name}"\n'
#       #         printf 'RESTIC_REST_PASSWORD="%s"\n' $(${lib.getExe pkgs.openssl} rand -base64 48 | tr -- '+/' '-_')
#       #       '';
#       #     };
#       #   };
#       #   "restic_crypt_${repo-name}" = {
#       #     rekeyFile = ../../secrets/sources/restic/repo_crypt_${repo-name}.age;
#       #     owner = "restic";
#       #     generator.script = "alnum";
#       #   };
#       # }));

#       # age.secrets."restic-server.htpasswd" = {
#       #   rekeyFile = ../../secrets/sources/restic/htpasswd.age;
#       #   owner = "restic";
#       #   generator = {
#       #     dependencies = restic-auth-files;
#       #     script =
#       #       {
#       #         lib,
#       #         pkgs,
#       #         decrypt,
#       #         deps,
#       #         ...
#       #       }:
#       #       ''
#       #         set -euo pipefail
#       #       ''
#       #       + (flip concatMapStrings deps (
#       #         {
#       #           name,
#       #           host,
#       #           file,
#       #         }:
#       #         ''
#       #           echo "Aggregating "${lib.escapeShellArg host}:${lib.escapeShellArg name} >&2

#       #           auth_data=$(${decrypt} ${escapeShellArg file})
#       #           user=$(echo "$auth_data" | grep "RESTIC_REST_USERNAME" | cut -d'"' -f2)
#       #           pass=$(echo "$auth_data" | grep "RESTIC_REST_PASSWORD" | cut -d'"' -f2)

#       #           echo "$pass" | ${pkgs.apacheHttpd}/bin/htpasswd -inBC 10 "$user"
#       #         ''
#       #       ));
#       #   };
#       # };

#       # age.secrets.restic_auth_rosetta = {
#       #   rekeyFile = ../../secrets/sources/restic/repo_auth_rosetta.age;
#       #   owner = "restic";
#       # };

#       # "universe/attic/token" = {
#       #   rekeyFile = ../../secrets/universe/attic/token.age;
#       #   owner = user.name;
#       # };

#       # # TODO: remove
#       # "universe/github/username" = {
#       #   rekeyFile = ../../secrets/universe/github/username.age;
#       #   intermediary = true;
#       # };
#       # "universe/github/password" = {
#       #   rekeyFile = ../../secrets/universe/github/password.age;
#       #   intermediary = true;
#       # };

#       # "universe/attic/config" = {
#       #   rekeyFile = ../../secrets/universe/attic/config.age;
#       #   generator = {
#       #     dependencies = {
#       #       token = config.age.secrets."universe/attic/token";
#       #     };
#       #     script =
#       #       { decrypt, deps, ... }:
#       #       ''
#       #         token="$(${decrypt} ${lib.escapeShellArg deps.token.file})"

#       #         cat <<EOF
#       #         default-server = "attic"

#       #         [servers.attic]
#       #         endpoint = "https://cache.${domain}"
#       #         token = "$token"
#       #         EOF
#       #       '';
#       #   };
#       #   owner = user.name;
#       #   path = "/home/${user.name}/.config/attic/config.toml";
#       # };

#       # "universe/nix-netrc" = {
#       #   rekeyFile = ../../secrets/nix-netrc.age;
#       #   generator = {
#       #     dependencies = {
#       #       atticToken = config.age.secrets."universe/attic/token";
#       #       githubUsername = config.age.secrets."universe/github/username";
#       #       githubPassword = config.age.secrets."universe/github/password";
#       #     };
#       #     script =
#       #       {
#       #         decrypt,
#       #         deps,
#       #         ...
#       #       }:
#       #       ''
#       #         token="$(${decrypt} ${lib.escapeShellArg deps.atticToken.file})"
#       #         github_username="$(${decrypt} ${lib.escapeShellArg deps.githubUsername.file})"
#       #         github_password="$(${decrypt} ${lib.escapeShellArg deps.githubPassword.file})"

#       #         cat <<EOF
#       #         machine cache.${domain} password $token
#       #         machine api.github.com login "$github_username" password "$github_password"
#       #         EOF
#       #       '';
#       #   };
#       #   owner = "root";
#       #   path = "/etc/nix/netrc";
#       # };

#       # age.secrets.nix-key = {
#       #   rekeyFile = ../../secrets/nix-key.age;
#       #   generator.script =
#       #     {
#       #       pkgs,
#       #       file,
#       #       ...
#       #     }:
#       #     ''
#       #       priv=$(${lib.getExe pkgs.nix} key generate-secret --key-name patrickdag.lel.lol-1)
#       #       ${lib.getExe pkgs.nix} key convert-secret-to-public <<< "$priv" > ${
#       #         lib.escapeShellArg (lib.removeSuffix ".age" file + ".pub")
#       #       }
#       #       echo "$priv"
#       #     '';
#       # };

#       # mkIf hasHomeSecrets {
#       #   age.secrets."user-identity-${hostConfig.mainUser}" = {
#       #     rekeyFile = identityBasePath + ".age";
#       #     generator.script = "age-identity";
#       #     owner = hostConfig.mainUser;
#       #   };
#       # })

#       # Create a dedicated user and group so we can control access to the socket.
#       # users.groups.etcd = { };
#       # users.users.etcd = {
#       #   isSystemUser = true;
#       #   group = "etcd";
#       # };

#       # # Configure the systemd service unit.
#       # systemd.services.etcd = {
#       #   wantedBy = [ "multi-user.target" ];
#       #   serviceConfig = {
#       #     Type = "notify";
#       #     User = "etcd";
#       #     ExecStart =
#       #       "${pkgs.etcd}/bin/etcd"
#       #       + " --data-dir /var/lib/etcd"
#       #       # Compaction is disabled by default, but that apparently risks the
#       #       # database eventually exploding on itself. Weird default.
#       #       + " --auto-compaction-retention=8h"
#       #       # Minimum set of options for secure local-only setup without auth.
#       #       # Access is limited to users in the 'etcd' group.
#       #       + " --listen-peer-urls unix:/run/etcd/peer"
#       #       + " --listen-client-urls unix:/run/etcd/grpc"
#       #       + " --listen-client-http-urls unix:/run/etcd/http"
#       #       # This is required but not actually used in our case.
#       #       + " --advertise-client-urls http://localhost:2379";
#       #     Restart = "on-failure";
#       #     RestartSec = 10;
#       #     # Actual data storage in /var/lib/etcd.
#       #     StateDirectory = "etcd";
#       #     StateDirectoryMode = "0700";
#       #     # Place our Unix sockets in /run/etcd.
#       #     RuntimeDirectory = "etcd";
#       #     RuntimeDirectoryMode = "0750";
#       #   };
#       #   postStart = ''
#       #     # Need to make sockets group-writable to allow connections.
#       #     chmod 0660 /run/etcd/{grpc,http}
#       #   '';
#       # };

#       # For the `etcdctl` tool.
#       environment.systemPackages = [ pkgs.etcd ];

#       # environment.persistence."/persist".directories = [
#       #   {
#       #     # directory = config.services.forgejo.stateDir;
#       #     # inherit (config.services.forgejo) user group;
#       #     # mode = "0700";
#       #   }
#       # ];
#     };
# }
{ }
