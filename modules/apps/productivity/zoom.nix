{
  flake.features.zoom.home =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.zoom-us
      ];

      # Without disabling xwayland, fonts are pixelated and look like 💩
      xdg.configFile."zoomus.conf" = {
        text = ''
          [General]
          xwayland=false
          enableWaylandShare=true
        '';
      };
    };
}
