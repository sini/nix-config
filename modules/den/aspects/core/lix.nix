{ den, inputs, ... }:
{
  den.aspects.core.lix = {
    nixos = {
      imports = [ inputs.lix-module.nixosModules.default ];
    };

    darwin = {
      imports = [ inputs.lix-module.darwinModules.default ];
    };
  };
}
