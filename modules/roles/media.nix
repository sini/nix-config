{ config, ... }:
{
  flake.modules.nixos.role_media = {
    imports = with config.flake.modules.nixos; [
      spotify-player
    ];

    home-manager.users.${config.flake.meta.user.username}.imports =
      with config.flake.modules.homeManager; [
        spotify-player
        mpv
        youtube-music-desktop
      ];
  };
}
