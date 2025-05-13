{ inputs, ... }:
let
  # Utility function to construct a package set based on the given system
  # along with the shared `nixpkgs` configuration defined in this repo.
  mkPkgsFor =
    system: pkgset:
    import pkgset {
      inherit system;
      config = {
        allowUnfree = true;
      };
    };
in
{
  imports = [
    (
      {
        lib,
        flake-parts-lib,
        ...
      }:
      flake-parts-lib.mkTransposedPerSystemModule {
        name = "pkgs";
        file = ./pkgs.nix;
        option = lib.mkOption {
          type = lib.types.unspecified;
        };
      }
    )
  ];

  perSystem =
    { system, ... }:
    {
      _module.args = rec {
        # Provide un-imported package set paths for reference in other modules.
        pkgsets = {
          unstable = inputs.nixpkgs-unstable;
          # Select the Nix package path based on the system being managed.
          nixpkgs =
            if (builtins.match ".*darwin" system != null) then inputs.nixpkgs-darwin else inputs.nixpkgs;
        };

        # Import the default Nix package set with the common config.
        pkgs = mkPkgsFor system pkgsets.nixpkgs;

        # Import the unstable Nix package set with the common config.
        unstable = mkPkgsFor system inputs.nixpkgs-unstable;

        # Select the home-manager input based on the system being managed.
        homeManager =
          if (builtins.match ".*darwin" system != null) then
            inputs.home-manager-darwin
          else
            inputs.home-manager;
      };
    };
}
