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
  groupDefs = config.groups or { };
in
{
  den.aspects.sudo = den.lib.perHost (
    { host }:
    let
      hostOptions = {
        hostname = host.name;
        inherit (host) system-access-groups;
        users = host.users or { };
      };
      resolvedUsers = resolveUsers lib canonicalUsers host.environment hostOptions groupDefs;
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
