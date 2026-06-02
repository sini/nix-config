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

  # Shared by os and home-manager (no longer using home-manager global pkgs).
  sharedOverlays = [
    # local packages under pkgs.local; canonical overlay defined in
    # modules/flake-parts/pkgs.nix
    self.overlays.default
  ]
  ++ builtins.attrValues (import (self + "/pkgs/overlays.nix") { inherit inputs; });
in
{
  den.aspects.core.nix.nixpkgs = {
    os.nixpkgs = {
      inherit config;
      overlays = [ inputs.proton-cachyos.overlays.default ] ++ sharedOverlays;
    };

    homeManager.nixpkgs = {
      inherit config;
      overlays = sharedOverlays;
    };
  };
}
