{
  flake.aspects.power-mgmt.nixos = {
    powerManagement = {
      enable = true;
      cpuFreqGovernor = "ondemand";
    };
  };
}
