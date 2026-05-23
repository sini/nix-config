{ den, ... }:
{
  den.aspects.hardware.adb = {
    os =
      { pkgs, ... }:
      {
        environment.systemPackages = [
          pkgs.android-tools
        ];
      };

    nixos =
      { pkgs, host, ... }:
      {
        environment.systemPackages = [
          pkgs.android-file-transfer
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
  };
}
