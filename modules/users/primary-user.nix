{ config, ... }:
let
  user = config.flake.meta.user;
in
{
  flake.modules.nixos.users =
    { config, ... }:
    {
      config.users = {
        mutableUsers = false;

        groups.${user.username}.gid = config.users.users.${user.username}.uid;

        users.${user.username} = {
          isNormalUser = true;
          initialHashedPassword = "$y$j9T$RpfkDk8AusZr9NS09tJ9e.$kbc4SL9Cu45o1YYPlyV1jiVTZZ/126ue5Nff2Rfgpw8";
          home = "/home/${user.username}";
          group = user.username;
          openssh.authorizedKeys.keys = user.ssh_keys;
          extraGroups = [
            "wheel"
            "audio"
            "sound"
            "video"
            "networkmanager"
            "input"
            "tty"
            "podman"
            "media"
          ];
          linger = true; # Required for the services start automatically without login
        };
      };
    };
}
