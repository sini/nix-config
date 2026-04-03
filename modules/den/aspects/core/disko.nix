{ den, inputs, ... }:
{
  den.aspects.disko = den.lib.perHost {
    nixos.imports = [ inputs.disko.nixosModules.disko ];
  };
}
