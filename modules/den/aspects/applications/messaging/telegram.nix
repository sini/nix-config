{
  den.aspects.applications.messaging.telegram = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.ayugram-desktop
        ];
      };
  };
}
