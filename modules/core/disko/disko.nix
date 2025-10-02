{ inputs, ... }:
{
  flake.features.disko.nixos = {
    imports = [ inputs.disko.nixosModules.disko ];
  };
}
