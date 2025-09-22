{
  flake.role.media = {
    nixosModules = [
      "spotify-player"
    ];

    homeManagerModules = [
      "spotify-player"
      "spicetify"
      "mpv"
      "youtube-music-desktop"
      "yt-dlp"
    ];
  };
}
