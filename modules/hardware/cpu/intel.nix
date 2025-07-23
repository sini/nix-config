{
  flake.modules.nixos.cpu-intel = {
    hardware.cpu.intel.updateMicrocode = true;
    boot.kernelModules = [ "kvm-intel" ];
    services.thermald.enable = true; # Enable thermald, the temperature management daemon. (only necessary if on Intel CPUs)
  };
}
