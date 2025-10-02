{
  flake.features.power-mgmt.nixos = {
    powerManagement = {
      enable = true;
      cpuFreqGovernor = "ondemand";
    };
  };
}
