{ lib, ... }:
{
  flake.modules.nixos.power-mgmt = {
    powerManagement = {
      enable = true;
      cpuFreqGovernor = lib.mkDefault "powersave";
    };
  };
}
