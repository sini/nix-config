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
      { pkgs, host, ... }:
      {
        environment.systemPackages = [
          pkgs.android-file-transfer
        ];
        # den host schema exposes system-owner, not user lists;
        # grant adbusers group to system-owner (covers primary user)
        users.users.${host.system-owner}.extraGroups = [ "adbusers" ];
      };
  };
}
