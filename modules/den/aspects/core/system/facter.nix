{ inputs, ... }:
{
  den.aspects.core.system.facter = {
    nixos =
      { host, ... }:
      {
        imports = [ inputs.nixos-facter-modules.nixosModules.facter ];
        facter = {
          reportPath = host.facterReport or null;
          detected = {
            dhcp.enable = false;
            graphics.enable = false;
          };
        };
      };
  };
}
