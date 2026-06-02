{ inputs, ... }:
{
  den.aspects.core.system.disko = {
    nixos = {
      imports = [ inputs.disko.nixosModules.disko ];
    };
  };
}
