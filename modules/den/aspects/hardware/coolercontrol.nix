{ den, ... }:
{
  den.aspects.hardware.coolercontrol = {
    nixos =
      {
        pkgs,
        lib,
        host,
        ...
      }:
      let
        isLaptop = host.hasAspect den.aspects.hardware.laptop;
      in
      {
        environment.systemPackages = lib.optionals (!isLaptop) [ pkgs.liquidctl ];

        programs.coolercontrol.enable = !isLaptop;
      };
  };
}
