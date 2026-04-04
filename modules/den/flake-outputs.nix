# Import den's flake output merge modules so both den and the old system
# can define nixosConfigurations/darwinConfigurations without conflict.
{ inputs, ... }:
{
  imports = [
    inputs.den.flakeOutputs.darwinConfigurations
  ];
}
