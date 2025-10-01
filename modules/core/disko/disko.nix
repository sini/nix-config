{ inputs, ... }:
{
  flake.aspects.disko.nixos = {
    imports = [ inputs.disko.nixosModules.disko ];
  };
}
