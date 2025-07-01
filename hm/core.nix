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
    git.enable = true; # ./modules/git.nix
    gpg.enable = true; # ./modules/gpg.nix
  };

  home.packages = with pkgs; [
    # Utilities
    ripgrep
    fd
    jq
  ];
}
