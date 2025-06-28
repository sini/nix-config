{ inputs, rootPath, ... }:
{
  flake.modules.nixos.agenix =
    { config, ... }:
    {
      imports = [
        inputs.agenix.nixosModules.default
        inputs.agenix-rekey.nixosModules.default
      ];

      age.rekey = {
        inherit (inputs.self.secretsConfig) masterIdentities;
        storageMode = "local";
        generatedSecretsDir = rootPath + "/.secrets/generated/${config.networking.hostName}";
        localStorageDir = rootPath + "/.secrets/rekeyed/${config.networking.hostName}";
      };

      # Custom generator for ssh-ed25519 since upstream doesn't seem to work
      # Reported issue here: https://github.com/oddlama/agenix-rekey/issues/104
      age.generators.ssh-ed25519-tmpdir =
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
    };
}
