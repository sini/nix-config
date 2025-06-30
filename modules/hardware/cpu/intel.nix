{
  flake.modules.nixos.cpu-intel = {
    hardware.cpu.intel.updateMicrocode = true;
    boot.kernelModules = [ "kvm-intel" ];
  };
}
