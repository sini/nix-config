{
  flake.features.agenix-generators.system =
    {
      config,
      lib,
      ...
    }:
    {
      age.generators = {
        ssh-ed25519-tmpdir =
          {
            lib,
            name,
            pkgs,
            ...
          }:
          ''
            (
              tmpdir=$(mktemp -d)
              trap 'rm -rf "$tmpdir"' EXIT
              ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" \
                -C ${lib.escapeShellArg "${config.networking.hostName}:${name}"} \
                -f "$tmpdir/key"
              cat "$tmpdir/key" >&3
            ) 3>&1 >/dev/null 2>&1
          '';

        age-identity =
          { pkgs, file, ... }:
          ''
            publicKeyFile=${lib.escapeShellArg (lib.removeSuffix ".age" file + ".pub")}
            ${pkgs.rage}/bin/rage-keygen 2> "$publicKeyFile"
            ${lib.getExe pkgs.gnused} 's/Public key: //' -i "$publicKeyFile"
          '';

        ssh-key =
          {
            pkgs,
            file,
            name,
            ...
          }:
          let
            target = config.networking.hostName or config.home.username;
          in
          ''
            publicKeyFile=${lib.escapeShellArg (lib.removeSuffix ".age" file + ".pub")}
            privateKey=$(exec 3>&1; ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" -C ${lib.escapeShellArg "${target}:${name}"} -f /proc/self/fd/3 <<<y >/dev/null 2>&1; true)
            echo "$privateKey" | ssh-keygen -f /proc/self/fd/0 -y > "$publicKeyFile"
            echo "$privateKey"
          '';

        shared-ssh-key =
          {
            pkgs,
            file,
            name,
            ...
          }:
          ''
            publicKeyFile=${lib.escapeShellArg (lib.removeSuffix ".age" file + ".pub")}
            privateKey=$(exec 3>&1; ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" -C ${lib.escapeShellArg "${name}"} -f /proc/self/fd/3 <<<y >/dev/null 2>&1; true)
            echo "$privateKey" | ssh-keygen -f /proc/self/fd/0 -y > "$publicKeyFile"
            echo "$privateKey"
          '';

        binary-cache-key =
          {
            pkgs,
            file,
            name,
            ...
          }:
          let
            target = config.networking.hostName or config.home.username;
            keyName = "${target}:${name}";
          in
          ''
            publicKeyFile=${lib.escapeShellArg (lib.removeSuffix ".age" file + ".pub")}
            tmpdir=$(mktemp -d)
            trap 'rm -rf "$tmpdir"' EXIT
            ${pkgs.nix}/bin/nix-store --generate-binary-cache-key \
              ${lib.escapeShellArg keyName} \
              "$tmpdir/private.pem" \
              "$publicKeyFile"
            cat "$tmpdir/private.pem"
          '';

        rfc3986-secret =
          { pkgs, ... }:
          ''
            # Generate an rfc3986 secret (URL-safe base64)
            secret=$(${pkgs.openssl}/bin/openssl rand -base64 54 | tr -d '\n' | tr '+/' '-_' | tr -d '=' | cut -c1-72)
            echo "$secret"
          '';

        hex32 =
          { pkgs, ... }:
          ''
            # Generate 32 bytes of random hex (64 hex characters)
            ${pkgs.openssl}/bin/openssl rand -hex 32
          '';
      };
    };
}
