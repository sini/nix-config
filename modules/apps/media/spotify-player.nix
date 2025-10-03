{ rootPath, ... }:
{
  flake.features.spotify-player = {
    home =
      { config, ... }:
      {
        age.secrets.spotify-player-credentials = {
          rekeyFile = rootPath + "/.secrets/users/${config.home.username}/spotify-player-credentials.age";
          mode = "640";
        };

        programs.spotify-player = {
          enable = true;
          settings = {
            client_id_command = "cat ${config.age.secrets.spotify-player-credentials.path}";
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
