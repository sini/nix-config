{ inputs, ... }:
{
  den.aspects.core.disko = {
    nixos = {
      imports = [ inputs.disko.nixosModules.disko ];
    };
  };
}
