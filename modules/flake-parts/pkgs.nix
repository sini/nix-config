{
  inputs,
  rootPath,
  withSystem,
  ...
}:
{
  imports = [
    inputs.pkgs-by-name-for-flake-parts.flakeModule
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
      _module.args.pkgs = import inputs.nixpkgs-unstable {
        inherit system;
        config = {
          allowUnfreePredicate = _pkg: true;
        };
        overlays = [
          # Add lix-module overlay first to make lixPackageSets available
          inputs.lix-module.overlays.default
        ]
        ++ builtins.attrValues (
          import (rootPath + "/pkgs/overlays.nix") {
            inherit inputs;
          }
        )
        ++ [
          inputs.nix-topology.overlays.default
        ];
      };
      pkgsDirectory = rootPath + "/pkgs/by-name";
    };

  flake = {
    overlays.default =
      _final: prev:
      withSystem prev.stdenv.hostPlatform.system (
        { config, ... }:
        {
          local = config.packages;
        }
      );
  };
}
