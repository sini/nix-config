# This file defines overlays
{ inputs, ... }:
{
  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = _final: prev: {
    zjstatus = inputs.zjstatus.packages.${prev.stdenv.hostPlatform.system}.default;
    nixidy = inputs.nixidy.packages.${prev.stdenv.hostPlatform.system}.default;
  };

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      inherit (final.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    };
  };
}
