_: {
  den.aspects.hardware.power-mgmt = {
    nixos = {
      powerManagement = {
        enable = true;
        cpuFreqGovernor = "ondemand";
      };
    };
  };
}
