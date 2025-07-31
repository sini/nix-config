{
  flake.modules.nixos.power-mgmt =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        powertop
      ];

      powerManagement = {
        enable = true;
        powertop.enable = true;
        cpuFreqGovernor = "ondemand";
      };
    };
}
