{ inputs, ... }:
{
  den.aspects.core.nix.lix = {
    nixos = {
      imports = [ inputs.lix-module.nixosModules.default ];
    };

    darwin = {
      imports = [ inputs.lix-module.darwinModules.default ];
    };
  };
}
