{ den, ... }:
{
  den.aspects.adb = den.lib.perHost (
    { host }:
    {
      nixos =
        { pkgs, ... }:
        {
          environment.systemPackages = [
            pkgs.android-tools
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
    }
  );
}
