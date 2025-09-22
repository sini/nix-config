{
  flake.role.media = {
    nixosModules = [
      "spotify-player"
    ];

    homeModules = [
      "spotify-player"
      "spicetify"
      "mpv"
      "youtube-music-desktop"
      "yt-dlp"
    ];
  };
}
