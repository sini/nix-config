{
  den.aspects.apps.messaging.zoom = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.zoom-us
        ];

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
