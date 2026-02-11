{ rootPath, ... }:
{
  flake.users.shuo = {
    configuration =
      { config, ... }:
      let
        username = "shuo";
      in
      {
        age.secrets."user-${username}-password" = {
          rekeyFile = rootPath + "/.secrets/users/${username}/hashed-password.age";
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
            hashedPasswordFile = config.age.secrets."user-${username}-password".path;
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
            linger = false;
          };
        };
      };
  };
}
