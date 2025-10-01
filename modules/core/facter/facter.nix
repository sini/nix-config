{ inputs, ... }:
{
  flake.aspects.facter = {
    nixos = {
      imports = [ inputs.nixos-facter-modules.nixosModules.facter ];
      facter.detected.dhcp.enable = false;
    };

    home =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [ nixos-facter ];
      };
  };
}
