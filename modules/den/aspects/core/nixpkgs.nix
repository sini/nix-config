{ den, inputs, withSystem, self, ... }:
{
  den.aspects.core.nixpkgs = {
    os =
      { ... }:
      {
        nixpkgs.config.allowUnfree = true;

        nixpkgs.overlays = [
          inputs.proton-cachyos.overlays.default

          # local packages under pkgs.local
          (
            _final: prev:
            withSystem prev.stdenv.hostPlatform.system (
              { config, ... }:
              {
                local = config.packages;
              }
            )
          )
        ] ++ builtins.attrValues (
          import (self + "/pkgs/overlays.nix") {
            inherit inputs;
          }
        );
      };
  };
}
