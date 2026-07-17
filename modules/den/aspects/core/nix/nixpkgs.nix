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
      { nixpkgs-overlays, lib, ... }:
      {
        nixpkgs = {
          inherit config;
          overlays = lib.unique nixpkgs-overlays;
        };
      };

    # The per-user home-manager nixpkgs. Included by the nixpkgs-overlays quirk's
    # home-own-nixpkgs policy ONLY when the host does not share its nixpkgs —
    # otherwise home-manager.useGlobalPkgs is enabled and setting nixpkgs.* here
    # trips home-manager's assertion. Collects the same nixpkgs-overlays as os, per
    # home scope.
    homeManager =
      {
        host,
        nixpkgs-overlays,
        lib,
        ...
      }:
      lib.mkIf (!host.settings.core.users.home-manager.useGlobalPkgs) {
        nixpkgs = {
          inherit config;
          overlays = lib.unique nixpkgs-overlays;
        };
      };
  };
}
