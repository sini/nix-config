{ den, ... }:
{
  den.aspects.roles.media = {
    colmena = [ "media" ];
    includes = with den.aspects; [
      apps.jellyfin-client
      apps.mpv
      apps.spicetify
      apps.qbittorrent
      apps.youtube-music
      apps.yt-dlp
    ];
  };
}
