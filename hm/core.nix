{
  lib,
  pkgs,
  ...
}:
{
  imports = import ./modules.nix { inherit lib; };

  programs = {
    bat.enable = true;
    eza.enable = true;
  };

  home.packages = with pkgs; [
    # Utilities
    ripgrep
    fd
    jq
  ];
}
