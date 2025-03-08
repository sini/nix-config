{
  config,
  ...
}:

{
  config = {
    users = {
      groups.media = {
        name = "media";
        inherit (users.deterministicIds.media) gid;
      };

      users.media = {
        inherit (users.deterministicIds.media) uid;
        group = "media";
        linger = true; # Required for the services start automatically without login
        isNormalUser = true;
        description = "Media user for rootless podman";
        extraGroups = [ "podman" ];
        shell = pkgs.bash;
      };
    };

    # Allow media user to use Home Manager
    nix.settings.allowed-users = [ "media" ];
  };
}
