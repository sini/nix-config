# Generate an SSH keypair with host-specific comment.
{
  features.agenix-generators.system =
    {
      config,
      lib,
      ...
    }:
    {
      age.generators.ssh-key =
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
    };
}
