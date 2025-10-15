{ inputs, ... }:
{
  flake.features.facter = {
    nixos =
      { hostOptions, ... }:
      {
        imports = [ inputs.nixos-facter-modules.nixosModules.facter ];
        facter.reportPath = hostOptions.facts;
        facter.detected.dhcp.enable = false;
        facter.detected.graphics.enable = false; # Don't configure graphics, we'll do that...
      };

    home =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [ nixos-facter ];
      };
  };
}
