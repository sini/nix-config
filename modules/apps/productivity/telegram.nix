{
  flake.features.telegram.home =
    { inputs, pkgs, ... }:
    {
      home.packages = [
        inputs.ayugram-desktop.packages.${pkgs.stdenv.hostPlatform.system}.ayugram-desktop
      ];
    };
}
