{ den, ... }:
{
  den.aspects.archive-tools = den.lib.perUser {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          atool
          unzip
          unrar
          cabextract
          p7zip
          zip
          xz
        ];
      };
  };
}
