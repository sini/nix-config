{
  flake.modules.nixos.power-mgmt = {
    powerManagement = {
      enable = true;
      cpuFreqGovernor = "ondemand";
    };
  };
}
