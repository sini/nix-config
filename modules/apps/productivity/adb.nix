{ config, ... }:
{
  flake.modules.nixos.adb =
    { pkgs, ... }:
    {
      users.users.${config.flake.meta.user.username}.extraGroups = [
        "adbusers"
      ];
      programs.adb.enable = true;

      services.udev.packages = [
        pkgs.android-udev-rules
      ];
    };
}
