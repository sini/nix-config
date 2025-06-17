{
  pkgs,
  #unstable,
  ...
}:
{
  #TODO: Enable OpenRazer support once 3.10.3 hist unstable
  #hardware.openrazer.enable = true;
  environment.systemPackages = with pkgs; [
    #unstable.openrazer-daemon
    polychromatic
  ];
  #hardware.openrazer.users = [ "sini" ];
}
