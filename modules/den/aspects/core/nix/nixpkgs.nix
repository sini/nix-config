{
  inputs,
  self,
  ...
}:
let
  config = {
    allowUnfree = true;
    allowDeprecatedx86_64Darwin = true;
  };
in
{
  den.aspects.core.nix.nixpkgs = {
    # Shared base overlays, contributed through the nixpkgs-overlays quirk so os
    # and home-manager collect them the same way as every other overlay.
    #
    # `local` (this flake's own packages, exposed as pkgs.local — cf.
    # self.overlays.default in modules/flake-parts/pkgs.nix) is rebuilt from den's
    # `self'.packages` rather than referencing `self.overlays.default`: forcing a
    # flake *output* inside den's pipeline re-enters the flake `outputs` fixpoint
    # (infinite recursion). `self'` is a resolved scope value and `self'.packages`
    # is the same `config.packages`, so it is safe to force here.
    nixpkgs-overlays =
      { self', ... }:
      [ (_final: _prev: { local = self'.packages; }) ]
      ++ builtins.attrValues (import (self + "/pkgs/overlays.nix") { inherit inputs; });

    os =
      {
        nixpkgs-overlays ? [ ],
        lib,
        ...
      }:
      {
        nixpkgs = {
          inherit config;
          # proton stays inline here until it moves onto the steam aspect.
          overlays = lib.unique ([ inputs.proton-cachyos.overlays.default ] ++ nixpkgs-overlays);
        };
      };

    homeManager =
      {
        nixpkgs-overlays ? [ ],
        lib,
        ...
      }:
      {
        nixpkgs = {
          inherit config;
          overlays = lib.unique nixpkgs-overlays;
        };
      };
  };
}
