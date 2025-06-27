{ config, ... }:
let
  user = config.flake.meta.user;
in
{
  flake.modules.nixos.users = {
    users = {
      groups.media = {
        name = "media";
      };

      users.media = {
        group = "media";
        linger = true; # Required for the services start automatically without login
        isNormalUser = true;
        description = "Media user for rootless podman";
        openssh.authorizedKeys.keys = user.ssh_keys; # Allow SSH access to media user by primary user
        extraGroups = [
          "video"
          "podman"
          "input"
          "tty"
        ];
      };
    };

    # Allow media user to use Home Manager
    nix.settings.allowed-users = [ "media" ];
  };
}
