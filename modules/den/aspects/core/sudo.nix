# Sudo and doas configuration with per-user rules from resolved users
{ den, ... }:
{
  den.aspects.sudo = den.lib.perHost (
    { host }:
    {
      nixos = {
        security = {
          sudo.enable = false;
          sudo-rs = {
            enable = true;
            execWheelOnly = true;
            wheelNeedsPassword = false;
          };

          doas = {
            enable = true;
            wheelNeedsPassword = false;
            extraRules = [
              {
                users = host.resolvedUsers.enabledNames;
                noPass = true;
                keepEnv = true;
              }
            ];
          };
        };
      };
    }
  );
}
