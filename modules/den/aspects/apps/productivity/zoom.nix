{ den, ... }:
{
  den.aspects.zoom = den.lib.perUser {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.zoom-us
        ];

        # Without disabling xwayland, fonts are pixelated
        xdg.configFile."zoomus.conf" = {
          text = ''
            [General]
            xwayland=false
            enableWaylandShare=true
          '';
        };
      };
  };
}
