{ inputs, ... }:
{
  flake.features.facter.linux =
    { hostOptions, ... }:
    {
      imports = [ inputs.nixos-facter-modules.nixosModules.facter ];
      facter = {
        reportPath = hostOptions.facts;
        detected = {
          dhcp.enable = false;
          graphics.enable = false; # Don't configure graphics, we'll do that...
        };
      };
    };
}
