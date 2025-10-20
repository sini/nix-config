{
  flake.features.xdg.home =
    {
      pkgs,
      ...
    }:
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
}
