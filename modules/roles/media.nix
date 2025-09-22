{ config, ... }:
{
  flake.role.media = {
    imports = with config.flake.modules.nixos; [
      spotify-player
    ];

    home-manager.users.${config.flake.meta.user.username}.imports =
      with config.flake.modules.homeManager; [
        spotify-player
        spicetify
        mpv
        youtube-music-desktop
        yt-dlp
      ];
  };
}
