{ den, ... }:
{
  den.aspects.telegram = den.lib.perUser {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.ayugram-desktop
        ];
      };
  };
}
