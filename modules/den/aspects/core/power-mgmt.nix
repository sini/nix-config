{ den, ... }:
{
  den.aspects.power-mgmt = den.lib.perHost {
    nixos.powerManagement = {
      enable = true;
      cpuFreqGovernor = "ondemand";
    };
  };
}
