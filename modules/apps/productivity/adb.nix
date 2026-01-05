{ config, ... }:
{
  flake.features.adb.nixos =
    { pkgs, ... }:
    {
      users.users.${config.flake.meta.user.username}.extraGroups = [
        "adbusers"
      ];

      environment.systemPackages = [
        pkgs.android-tools
        pkgs.android-file-transfer # => <https://github.com/whoozle/android-file-transfer-linux>
      ];
    };
}
