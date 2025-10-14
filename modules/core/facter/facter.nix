{ inputs, ... }:
{
  flake.features.facter = {
    nixos = {
      imports = [ inputs.nixos-facter-modules.nixosModules.facter ];
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
