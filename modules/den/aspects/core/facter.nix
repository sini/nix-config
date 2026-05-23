{ inputs, ... }:
{
  den.aspects.core.facter = {
    nixos =
      { host, ... }:
      {
        imports = [ inputs.nixos-facter-modules.nixosModules.facter ];
        facter.reportPath = host.facts or null;
      };
  };
}
