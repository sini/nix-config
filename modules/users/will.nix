{ rootPath, ... }:
{
  flake.user.will = {
    userConfig =
      { config, ... }:
      {
        age.secrets.user-will-password = {
          rekeyFile = rootPath + "/.secrets/user-passwords/will.age";
        };

        users = {
          deterministicIds.will = {
            uid = 1002;
            gid = 1002;
            subUidRanges = [
              {
                startUid = 296608;
                count = 65536;
              }
            ];
            subGidRanges = [
              {
                startGid = 296608;
                count = 65536;
              }
            ];
          };

          groups.will.gid = config.users.users.will.uid;

          users.will = {
            isNormalUser = true;
            hashedPasswordFile = config.age.secrets.user-will-password.path;
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
