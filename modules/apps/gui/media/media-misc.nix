{ config, rootPath, ... }:
{
  flake.modules.nixos.media = {

    age.secrets.spotify-player-credentials = {
      rekeyFile = rootPath + "/.secrets/user/spotify-player-credentials.age";
      owner = config.flake.meta.user.username;
      group = config.flake.meta.user.username;
      mode = "640";
    };

  };

  flake.modules.homeManager.media =
    { pkgs, osConfig, ... }:
    {
      home.packages = with pkgs; [
        ytmdesktop # YouTube Music desktop client
      ];

      # spotify-player tui
      programs.spotify-player = {
        enable = true;
        settings = {
          # NOTE: not working
          client_id_command = "cat ${osConfig.age.secrets.spotify-player-credentials.path}";
          liked_icon = "";
          device = {
            volume = 85;
            autoplay = true;
          };
        };
      };
    };
}
