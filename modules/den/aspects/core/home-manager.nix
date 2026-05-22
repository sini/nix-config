# Home-manager NixOS module configuration.
# Den's home-manager battery handles importing the HM NixOS module itself.
# This aspect just sets shared config (useGlobalPkgs, useUserPackages).
{ den, ... }:
{
  den.aspects.core.home-manager = {
    nixos = {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
    };
  };
}
