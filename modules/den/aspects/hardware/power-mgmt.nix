{
  den.aspects.hardware.power-mgmt = {
    nixos =
      { lib, ... }:
      {
        powerManagement = {
          enable = true;
          cpuFreqGovernor = lib.mkDefault "powersave";
        };
      };
  };
}
