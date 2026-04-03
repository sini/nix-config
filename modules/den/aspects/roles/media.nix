# Media role: media players, downloaders, and streaming clients.
{ den, ... }:
{
  den.aspects.media = {
    includes = [
      den.aspects.jellyfin-client
      den.aspects.mpv
      den.aspects.spicetify
      den.aspects.qbittorrent
      den.aspects.youtube-music-desktop
      den.aspects.yt-dlp
    ];
  };
}
