{ config, ... }:
{
  flake.features.adb.system =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        pkgs.android-tools
      ];
    };

  flake.features.adb.linux =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        pkgs.android-file-transfer # => <https://github.com/whoozle/android-file-transfer-linux>
      ];
      users.users.${config.flake.meta.user.username}.extraGroups = [
        "adbusers"
      ];
    };
}
