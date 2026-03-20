# Generate a Tailscale pre-authentication key by SSHing to the headscale host.
# settings.headscaleHost: IP or hostname of the headscale server
# settings.user: headscale user to create/use for the preauthkey
{
  features.agenix-generators.system =
    { lib, ... }:
    {
      age.generators.tailscale-preauthkey =
        {
          pkgs,
          secret,
          name,
          ...
        }:
        let
          inherit (lib) escapeShellArg;
          inherit (lib.trivial) throwIfNot;
          inherit (lib) isAttrs isString;
          inherit (secret) settings;
          ssh = "${pkgs.openssh}/bin/ssh -o StrictHostKeyChecking=accept-new root@${escapeShellArg settings.headscaleHost}";
          jq = "${pkgs.jq}/bin/jq";
          user = escapeShellArg settings.user;
        in
        throwIfNot (isAttrs settings) "Secret '${name}' must have a `settings` attrset."
          throwIfNot (isString settings.headscaleHost) "Secret '${name}' is missing a `headscaleHost` string."
          throwIfNot (isString settings.user) "Secret '${name}' is missing a `user` string."
          ''
            set -euo pipefail

            # Create user if it doesn't exist
            if ! ${ssh} headscale users list -o json | ${jq} -e --arg u ${user} '.[] | select(.name == $u)' >/dev/null 2>&1; then
              ${ssh} headscale users create ${user} >&2
            fi

            # Get the numeric user ID
            user_id=$(${ssh} headscale users list -o json | ${jq} -r --arg u ${user} '.[] | select(.name == $u) | .id')

            # Create preauthkey (only the key goes to stdout)
            ${ssh} headscale preauthkeys create --user "$user_id" --reusable --expiration 99y
          '';
    };
}
