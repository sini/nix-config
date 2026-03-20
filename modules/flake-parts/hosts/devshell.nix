{
  perSystem =
    { config, ... }:
    {
      devshells.default.commands = [
        {
          package = config.packages.update-host-keys;
          name = "update-host-keys";
          help = "Collect and encrypt SSH host keys from all configured hosts";
        }
        {
          package = config.packages.nix-flake-provision-keys;
          name = "nix-flake-provision-keys";
          help = "Provision SSH host keys and disk encryption secrets for a NixOS host";
        }
        {
          package = config.packages.nix-flake-install;
          name = "nix-flake-install";
          help = "Install NixOS remotely using nixos-anywhere with SSH keys and disk encryption";
        }
        {
          package = config.packages.impermanence-copy;
          name = "impermanence-copy";
          help = "Copy existing data to impermanence persistent storage for a host";
        }
        {
          package = config.packages.update-tang-disk-keys;
          name = "update-tang-disk-keys";
          help = "Update disk encryption keys using Tang servers and TPM2";
        }
      ];
    };
}
