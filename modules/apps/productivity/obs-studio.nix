{
  flake.features.obs-studio.home =
    { pkgs, ... }:
    {
      home = {
        packages = [
          pkgs.obs-cmd
        ];
        sessionVariables = {
          OBS_VKCAPTURE_QUIET = "1";
        };
      };
      programs.obs-studio = {
        enable = true;
        plugins = with pkgs.obs-studio-plugins; [
          #obs-backgroundremoval
          #obs-gstreamer
          #obs-pipewire-audio-capture
          #obs-tuna
          #obs-vaapi
          #obs-vkcapture
          #input-overlay
          #droidcam-obs
          wlrobs
        ];
      };
    };
}
