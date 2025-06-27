{ inputs, ... }:
{
  flake.modules.nixos.disko = {
    imports = [ inputs.disko.nixosModules.disko ];
  };
}
