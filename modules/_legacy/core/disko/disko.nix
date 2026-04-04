{ inputs, ... }:
{
  features.disko.linux = {
    imports = [ inputs.disko.nixosModules.disko ];
  };
}
