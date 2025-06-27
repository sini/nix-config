{
  pkgs,
  ...
}:
{
  #TODO: Make this a module
  config = {
    hardware.openrazer.enable = true;
    environment.systemPackages = with pkgs; [
      openrazer-daemon
      polychromatic
    ];
    hardware.openrazer.users = [ "sini" ];
  };
}
