{ den, ... }:
{
  den.aspects.xdg = den.lib.perUser {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          xdg-utils
        ];

        xdg = {
          enable = true;
          userDirs = {
            enable = true;
          };
        };
      };
  };
}
