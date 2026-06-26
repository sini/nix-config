{ rootPath, ... }:
{
  # The `member` collector fans per-user via roles.default, so its homeManager
  # block sees `replicateHome`. When a user actually replicates a home dir, mint
  # a per-(user,host) Syncthing device identity: the agenix-rekey generator
  # writes the cert (`.crt`) and device-id (`.id`) sidecars next to the secret
  # and emits the private key on stdout (which agenix-rekey encrypts).
  #
  # Defined inline rather than imported from _generators-module.nix: that module
  # is host-shaped (references config.networking.fqdn) and would not bind inside
  # home-manager.
  den.aspects.core.network.syncthing.member.homeManager =
    {
      replicateHome,
      user,
      host,
      lib,
      ...
    }:
    let
      dirs = lib.unique (lib.concatMap (e: e.directories or [ ]) replicateHome);
    in
    lib.mkIf (dirs != [ ]) {
      age.generators.syncthing-identity =
        { pkgs, file, ... }:
        let
          syncthing = "${pkgs.syncthing}/bin/syncthing";
        in
        ''
          set -euo pipefail
          tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
          # Suppress generate's chatty stdout (only key.pem may reach the secret);
          # let stderr surface so a failure is visible, and `set -e` aborts before
          # `cat key.pem` so a failed generate never emits a garbage identity.
          ${syncthing} generate --home="$tmp" >/dev/null
          base=${lib.escapeShellArg (lib.removeSuffix ".age" file)}
          cp "$tmp/cert.pem" "$base.crt"
          ${syncthing} --home="$tmp" device-id > "$base.id"
          cat "$tmp/key.pem"
        '';

      age.secrets.syncthing-identity = {
        rekeyFile = rootPath + "/.secrets/users/${user.name}/syncthing-${host.name}.age";
        generator.script = "syncthing-identity";
      };
    };
}
