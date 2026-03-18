# Generate a shared SSH keypair (without host-specific comment).
{
  flake.features.agenix-generators.system =
    { lib, ... }:
    {
      age.generators.shared-ssh-key =
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
    };
}
