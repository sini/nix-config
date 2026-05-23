_: {
  den.aspects.hardware.cpu-intel = {
    nixos = {
      hardware.cpu.intel.updateMicrocode = true;
      boot.kernelModules = [ "kvm-intel" ];
      services.thermald.enable = true;
    };
  };
}
