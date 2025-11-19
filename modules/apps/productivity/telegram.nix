{
  flake.features.telegram.home =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.ayugram-desktop
      ];
    };
}
