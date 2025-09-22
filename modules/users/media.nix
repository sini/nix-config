{
  flake.user.media =
    { config, lib, ... }:
    {
      userConfig = {
        users = {
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
      homeModules = [ ];
    };
}
