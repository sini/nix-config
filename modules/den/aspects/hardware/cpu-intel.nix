{ den, ... }:
{
  den.aspects.cpu-intel = den.lib.perHost {
    nixos = {
      hardware.cpu.intel.updateMicrocode = true;
      boot.kernelModules = [ "kvm-intel" ];
      services.thermald.enable = true;
    };
  };
}
