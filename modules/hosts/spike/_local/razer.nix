{
  config,
  pkgs,
  ...
}:
{
  config = {
    hardware.openrazer.enable = true;
    environment.systemPackages = with pkgs; [
      openrazer-daemon
      polychromatic
    ];
    hardware.openrazer.users = [ config.node.mainUser ];
  };
}
