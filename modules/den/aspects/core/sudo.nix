# Sudo and doas configuration with per-user rules from resolved users
{
  den,
  self,
  config,
  lib,
  ...
}:
let
  inherit (self.lib.users) resolveUsers;
  canonicalUsers = config.users or { };
  allEnvironments = config.environments or { };
  groupDefs = config.groups or { };
in
{
  den.aspects.sudo = den.lib.perHost (
    { host }:
    let
      envName = host.environment or "dev";
      environment = allEnvironments.${envName} or { };
      hostOptions = {
        hostname = host.name;
        system-access-groups = host.system-access-groups or [ ];
        users = host.users or { };
      };
      resolvedUsers = resolveUsers lib canonicalUsers environment hostOptions groupDefs;
      enabledUserNames = builtins.attrNames (
        lib.filterAttrs (_: u: u.system.enable or false) resolvedUsers
      );
    in
    {
      nixos = {
        security = {
          # Enable sudo-rs instead of c-based sudo
          sudo.enable = false;
          sudo-rs = {
            enable = true;
            execWheelOnly = true;
            wheelNeedsPassword = false;
          };

          # Enable and configure doas with per-user rules
          doas = {
            enable = true;
            wheelNeedsPassword = false;
            extraRules = [
              {
                users = enabledUserNames;
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
