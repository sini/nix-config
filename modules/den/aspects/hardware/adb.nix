_:
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
      { pkgs, host, lib, ... }:
      {
        environment.systemPackages = [
          pkgs.android-file-transfer
        ];
        users.users = lib.genAttrs (builtins.attrNames host.users) (_: {
          extraGroups = [ "adbusers" ];
        });
      };
  };
}
