{ config, ... }:
{
  flake.features.adb.nixos =
    { pkgs, ... }:
    {
      users.users.${config.flake.meta.user.username}.extraGroups = [
        "adbusers"
      ];
      programs.adb.enable = true;

      environment.systemPackages = [
        pkgs.android-file-transfer # => <https://github.com/whoozle/android-file-transfer-linux>
      ];
      services.udev.packages = [
        pkgs.android-udev-rules
      ];
    };
}
