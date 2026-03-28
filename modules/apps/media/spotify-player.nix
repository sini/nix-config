{ rootPath, ... }:
{
  features.spotify-player = {
    home =
      { config, secrets, ... }:
      {
        age.secrets.spotify-player-credentials = {
          rekeyFile = rootPath + "/.secrets/users/${config.home.username}/spotify-player-credentials.age";
          mode = "640";
        };

        programs.spotify-player = {
          enable = true;
          settings = {
            client_id_command = "cat ${secrets.spotify-player-credentials}";
            enable_media_control = true;
            enable_notify = false;
            enable_cover_image_cache = true;
            playback_format = "          {status} {track} • {artists}\n          {album}\n          {metadata}";
            liked_icon = "";
            device = {
              name = "spotify_player";
              device_type = "L1";
              volume = 100;
              bitrate = 320;
              audio_cache = true;
              normalization = false;
              autoplay = true;
            };
            layout = {
              playback_window_position = "Bottom";
            };
          };
        };
      };
  };
}
