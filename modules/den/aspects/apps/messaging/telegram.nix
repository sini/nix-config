{ den, ... }:
{
  den.aspects.apps.telegram = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.ayugram-desktop
        ];
      };
  };
}
