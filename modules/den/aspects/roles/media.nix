{ den, ... }:
{
  den.aspects.roles.media = {
    includes = with den.aspects; [
      applications.media.jellyfin-client
      applications.media.mpv
      applications.media.spicetify
      applications.media.qbittorrent
      applications.media.youtube-music
      applications.media.yt-dlp
    ];
  };
}
