{ den, ... }:
{
  den.aspects.roles.media = {
    includes = with den.aspects; [
      apps.media.jellyfin-client
      apps.media.mpv
      apps.media.spicetify
      apps.media.qbittorrent
      apps.media.youtube-music
      apps.media.yt-dlp
    ];
  };
}
