{
  flake.modules.homeManager.firefox =
    { pkgs, ... }:
    {
      programs.firefox = {
        enable = true;
        profiles = {
          default = {
            extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
              bitwarden
            ];
            id = 0;
            isDefault = true;
            settings = {
              # Hardware Video Decoding, see https://wiki.archlinux.org/title/Firefox
              "gfx.webrender.all" = true;
              "media.ffmpeg.vaapi.enabled" = true;
              "media.hardware-video-decoding.force-enabled" = true;
            };
          };
        };
      };
    };
}
