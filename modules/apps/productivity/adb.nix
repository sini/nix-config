{
  features.adb.system =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        pkgs.android-tools
      ];
    };

  features.adb.linux =
    {
      lib,
      pkgs,
      users,
      ...
    }:
    let
      enabledUserNames = builtins.attrNames (lib.filterAttrs (_: u: u.system.enable or false) users);
    in
    {
      environment.systemPackages = [
        pkgs.android-file-transfer # => <https://github.com/whoozle/android-file-transfer-linux>
      ];
      users.users = builtins.listToAttrs (
        map (userName: {
          name = userName;
          value = {
            extraGroups = [ "adbusers" ];
          };
        }) enabledUserNames
      );
    };
}
