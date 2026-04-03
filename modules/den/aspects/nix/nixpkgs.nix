{
  den,
  inputs,
  withSystem,
  rootPath,
  ...
}:
{
  den.aspects.nixpkgs = den.lib.perHost {
    os = {
      nixpkgs = {
        config = {
          allowUnfree = true;
          allowDeprecatedx86_64Darwin = true;
        };

        overlays = [
          inputs.proton-cachyos.overlays.default

          # Custom packages from pkgs/ directory under `pkgs.local`
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
    };
  };
}
