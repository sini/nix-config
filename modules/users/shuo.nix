{
  flake.user.shuo = {
    userConfig =
      { config, ... }:
      {
        users = {
          deterministicIds.shuo = {
            uid = 1001;
            gid = 1001;
          };

          groups.shuo.gid = config.users.users.shuo.uid;

          users.shuo = {
            isNormalUser = true;
            initialHashedPassword = "$y$j9T$RpfkDk8AusZr9NS09tJ9e.$kbc4SL9Cu45o1YYPlyV1jiVTZZ/126ue5Nff2Rfgpw8";
            home = "/home/shuo";
            group = "shuo";
            openssh.authorizedKeys.keys = [ ];
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
              "gamemode"
              "render"
            ];
            linger = true;
          };
        };
      };
    homeModules = [ ];
  };
}
