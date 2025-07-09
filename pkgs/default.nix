# Can build them using 'nix build .#pkgname'
{ pkgs, ... }:
{
  zsh-skim-histdb = pkgs.callPackage ./zsh-skim-histdb { };
}
