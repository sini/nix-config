{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:
let
  enableDirenv = config.programs.direnv.enable;
in
{
  imports = import ./modules.nix { inherit inputs lib; };

  programs = {
    bat.enable = true;
    eza.enable = true;
    git.enable = true; # ./modules/git.nix
    gpg.enable = true; # ./modules/gpg.nix
    direnv.enable = true; # ./modules/direnv.nix
    direnv.nix-direnv.enable = lib.mkIf enableDirenv true;
  };

  home.packages = with pkgs; [
    # Utilities
    ripgrep
    fd
    jq
  ];
}
