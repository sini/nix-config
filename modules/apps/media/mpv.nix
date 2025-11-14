{
  flake.features.mpv.home =
    { pkgs, ... }:
    {
      programs.mpv = {
        enable = true;

        config = {
          ytdl-format = "bestvideo+bestaudio";
          slang = "eng,en";
          alang = "jpn,jap,ja,jp";
          hwdec = "auto";
          hwdec-codecs = "all";
          profile = "gpu-hq";
          vo = "gpu";
          gpu-api = "opengl";
        };

        bindings = {
          a = "cycle audio";
          s = "cycle sub";
          WHEEL_UP = "add volume 2.5";
          WHEEL_DOWN = "add volume -2.5";
          UP = "add volume 2.5";
          DOWN = "add volume -2.5";
          ENTER = "ignore";
          "=" = "add video-zoom 0.1";
          "-" = "add video-zoom -0.1";
          "alt+=" = "add video-rotate 90";
          "alt+-" = "add video-rotate -90";
        };

        scripts = with pkgs.mpvScripts; [
          inhibit-gnome # do not let gnome sleep during playback
          mpris # integrate with media controls
          autoload # load playlist entries from play dir
        ];

        scriptOpts = {
          autoload = {
            disabled = false;
            images = false;
            videos = true;
            audio = true;
            ignore_hidden = true;
            same_type = true;
            directory_mode = "ignore";
          };
        };
      };
    };
}
