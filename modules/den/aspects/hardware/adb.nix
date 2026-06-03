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
      {
        pkgs,
        resolved-users,
        lib,
        ...
      }:
      {
        environment.systemPackages = [
          pkgs.android-file-transfer
        ];
        users.users = lib.genAttrs (map (u: u.name) resolved-users) (_: {
          extraGroups = [ "adbusers" ];
        });
      };
  };
}
