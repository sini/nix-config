{ inputs, ... }:
{
  flake.features.nix = {
    linux = {
      imports = [ inputs.lix-module.nixosModules.default ];
    };

    darwin = {
      imports = [ inputs.lix-module.darwinModules.default ];
    };
  };
}
