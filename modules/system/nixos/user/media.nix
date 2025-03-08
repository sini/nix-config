{
  config,
  ...
}:
let
  mediaIds = config.users.deterministicIds;
in
{
  config = {
    users = {
      groups.media = {
        inherit (mediaIds) gid;
        name = "media";
      };

      users.media = {
        inherit (mediaIds) uid;
        group = "media";
        linger = true; # Required for the services start automatically without login
        isNormalUser = true;
        description = "Media user for rootless podman";
        extraGroups = [ "podman" ];
      };
    };

    # Allow media user to use Home Manager
    nix.settings.allowed-users = [ "media" ];
  };
}
