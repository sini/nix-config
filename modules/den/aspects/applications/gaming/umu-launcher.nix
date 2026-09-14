# umu-launcher (github:Open-Wine-Components/umu-launcher): the unified launcher
# GloriousEggroll points to now that wine-ge-custom is archived (last release
# GE-Proton8-26, 2024-02-04). It runs GE-Proton outside Steam through the same
# pressure-vessel runtime Steam uses, so Lutris/Heroic and one-off Windows
# binaries get the Proton stack rather than a separate, diverging Wine build.
#
# Taken as an overlay rather than packages.*: upstream's overlay builds on the
# nixpkgs umu-launcher, so the rest of the package set stays coherent.
{
  flake-file.inputs.umu = {
    url = "github:Open-Wine-Components/umu-launcher?dir=packaging/nix";
    inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  den.aspects.applications.gaming.umu-launcher = {
    nixpkgs-overlays =
      { inputs', ... }:
      [ inputs'.umu.overlays.default ];

    homeManager =
      { pkgs, ... }:
      {
        # The wrapped package pulls in the steam FHS env (i686 multilib) needed
        # to run 32-bit Windows games; umu-launcher-unwrapped omits it.
        home.packages = [ pkgs.umu-launcher ];
      };
  };
}
