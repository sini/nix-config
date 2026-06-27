{
  inputs,
  rootPath,
  withSystem,
  ...
}:
{
  imports = [
    inputs.pkgs-by-name-for-flake-parts.flakeModule
  ];

  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = import inputs.nixpkgs-unstable {
        inherit system;
        config = {
          allowUnfree = true;
          allowDeprecatedx86_64Darwin = true;
        };
        overlays = builtins.attrValues (import (rootPath + "/pkgs/overlays.nix") { inherit inputs; }) ++ [
          inputs.nix-topology.overlays.default
        ];
      };
      pkgsDirectory = rootPath + "/pkgs/by-name";
    };

  # local packages under pkgs.local; consumed by the den core.nixpkgs aspect
  flake.overlays.default =
    _final: prev:
    withSystem prev.stdenv.hostPlatform.system (
      { config, ... }:
      {
        local = config.packages;
      }
    );
}
