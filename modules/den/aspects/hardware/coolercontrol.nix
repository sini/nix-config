{ den, ... }:
{
  den.aspects.hardware.coolercontrol = {
    nixos =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.liquidctl ];

        programs.coolercontrol.enable = true;
      };
  };
}
