# OBS Studio. The nixpkgs build + plugin set are Linux-only (pipewire, vaapi,
# vkcapture, wlrobs), so macOS gets OBS via the `obs` cask. obs-cmd is portable.
{
  den.aspects.apps.productivity.obs-studio = {
    homebrew-cask = [ "obs" ];

    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.obs-cmd ];
      };

    homeLinux =
      { pkgs, ... }:
      {
        home.sessionVariables.OBS_VKCAPTURE_QUIET = "1";
        programs.obs-studio = {
          enable = true;
          plugins = with pkgs.obs-studio-plugins; [
            obs-backgroundremoval
            obs-gstreamer
            obs-pipewire-audio-capture
            obs-tuna
            obs-vaapi
            obs-vkcapture
            input-overlay
            wlrobs
          ];
        };
      };
  };
}
