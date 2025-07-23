{ config, ... }:
{
  flake.modules.nixos.adb = {
    users.users.${config.flake.meta.user.username}.extraGroups = [
      "adbusers"
    ];
    programs.adb.enable = true;
  };
}
