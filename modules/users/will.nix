{
  flake.user.will = {
    userConfig =
      { config, ... }:
      {
        users = {
          deterministicIds.will = {
            uid = 1002;
            gid = 1002;
          };

          groups.will.gid = config.users.users.will.uid;

          users.will = {
            isNormalUser = true;
            initialHashedPassword = "$y$j9T$RpfkDk8AusZr9NS09tJ9e.$kbc4SL9Cu45o1YYPlyV1jiVTZZ/126ue5Nff2Rfgpw8";
            home = "/home/will";
            group = "will";
            openssh.authorizedKeys.keys = [
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMKKUMmeJtEOYi6rU0tumxlrZjH9Y3FCyOhVFIpu3LF1 will.t.bryant@gmail.com"
            ];
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
