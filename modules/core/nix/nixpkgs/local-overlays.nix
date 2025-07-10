{
  inputs,
  withSystem,
  rootPath,
  ...
}:
{
  flake.modules.nixos.nixpkgs =
    { hostOptions, ... }:
    {
      nixpkgs.pkgs = import (if hostOptions.unstable then inputs.nixpkgs else inputs.nixpkgs-unstable) {
        inherit (hostOptions) system;
      };
      nixpkgs.overlays =
        [
          # This brings our custom packages from the 'pkgs' directory under `pkgs.local`
          # provided with inputs.pkgs-by-name-for-flake-parts.flakeModule
          (
            _final: prev:
            withSystem prev.stdenv.hostPlatform.system (
              { config, ... }:
              {
                local = config.packages;
              }
            )
          )
        ]
        ++ builtins.attrValues (
          import (rootPath + "/pkgs/overlays.nix") {
            inherit inputs;
          }
        );
    };
}
