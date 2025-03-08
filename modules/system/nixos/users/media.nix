{
  config,
  ...
}:

{
  config = {
    users = {
      groups.media = {
        name = "media";
      };

      users.media = {
        group = "media";
        linger = true; # Required for the services start automatically without login
        isNormalUser = true;
        autoSubUidGidRange = false;
        description = "Media user for rootless podman";
        extraGroups = [ "podman" ];
      };
    };

    # Allow media user to use Home Manager
    nix.settings.allowed-users = [ "media" ];
  };
}
