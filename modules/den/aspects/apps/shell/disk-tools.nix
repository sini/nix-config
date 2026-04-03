{ den, ... }:
{
  den.aspects.disk-tools = den.lib.perUser {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          dust
          dua
          dysk
          ncdu
        ];
      };
  };
}
