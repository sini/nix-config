{
  den.aspects.apps.messaging.telegram = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.ayugram-desktop
        ];
      };
  };
}
