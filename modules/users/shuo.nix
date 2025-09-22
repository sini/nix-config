{ rootPath, ... }:
{
  flake.user.shuo = {
    userConfig =
      { config, ... }:
      {
        age.secrets.user-shuo-password = {
          rekeyFile = rootPath + "/.secrets/user-passwords/shuo.age";
        };
        users = {
          deterministicIds.shuo = {
            uid = 1001;
            gid = 1001;
            subUidRanges = [
              {
                startUid = 231072;
                count = 65536;
              }
            ];
            subGidRanges = [
              {
                startGid = 231072;
                count = 65536;
              }
            ];
          };

          groups.shuo.gid = config.users.users.shuo.uid;

          users.shuo = {
            isNormalUser = true;
            hashedPasswordFile = config.age.secrets.user-shuo-password.path;
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
