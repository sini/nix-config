{ config, ... }:
{
  flake.modules.nixos.razer =
    { pkgs, ... }:
    {
      hardware.openrazer.enable = true;
      environment.systemPackages = with pkgs; [
        openrazer-daemon
        polychromatic
      ];
      hardware.openrazer.users = [ config.flake.meta.user.username ];
    };

}
