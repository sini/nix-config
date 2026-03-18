{ inputs, ... }:
{
  flake.features.facter.linux =
    { host, ... }:
    {
      imports = [ inputs.nixos-facter-modules.nixosModules.facter ];
      facter = {
        reportPath = host.facts;
        detected = {
          dhcp.enable = false;
          graphics.enable = false; # Don't configure graphics, we'll do that...
        };
      };
    };
}
