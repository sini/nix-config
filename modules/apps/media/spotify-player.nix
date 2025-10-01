{ config, rootPath, ... }:
{
  flake.aspects.spotify-player = {
    nixos = {
      age.secrets.spotify-player-credentials = {
        rekeyFile = rootPath + "/.secrets/user/spotify-player-credentials.age";
        owner = config.flake.meta.user.username;
        group = config.flake.meta.user.username;
        mode = "640";
      };
    };

    home =
      { osConfig, ... }:
      {
        programs.spotify-player = {
          enable = true;
          settings = {
            client_id_command = "cat ${osConfig.age.secrets.spotify-player-credentials.path}";
            liked_icon = "";
            device = {
              volume = 85;
              autoplay = true;
            };
          };
        };
      };
  };
}
