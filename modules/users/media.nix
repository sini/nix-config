{
  flake.users.media = {
    userConfig =
      { config, lib, ... }:
      {
        users = {
          deterministicIds.media = {
            # Maps to Synology NAS user/group for docker user
            uid = 1027;
            gid = 65536;
            subUidRanges = [
              {
                startUid = 165536;
                count = 65536;
              }
            ];
            subGidRanges = [
              {
                startGid = 165536;
                count = 65536;
              }
            ];
          };

          groups.media = {
            name = "media";
          };

          users.media = {
            group = "media";
            linger = true; # Required for the services start automatically without login
            isNormalUser = true;
            description = "Media user for rootless podman";
            openssh.authorizedKeys.keys =
              with lib;
              concatLists (
                mapAttrsToList (
                  _name: user: if elem "media" user.extraGroups then user.openssh.authorizedKeys.keys else [ ]
                ) config.users.users
              );
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
  };
}
