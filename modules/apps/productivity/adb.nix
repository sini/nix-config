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
      pkgs,
      host,
      ...
    }:
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
        }) host.users.enabledNames
      );
    };
}
