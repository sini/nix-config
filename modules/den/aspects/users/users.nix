# Full ACL-driven user provisioning for den hosts.
# Reads canonical users, environments, and groups from the existing flake-parts
# config, calls resolveUsers, and generates NixOS user accounts.
{
  den,
  self,
  config,
  lib,
  rootPath,
  ...
}:
let
  # Access the existing resolveUsers function from flake-parts lib
  inherit (self.lib.users) resolveUsers;

  # Flake-level data (still defined in the old system alongside den)
  canonicalUsers = config.users or { };
  groupDefs = config.groups or { };

  # Build Unix account config for a single resolved user
  buildUnixAccountConfig =
    userName: user:
    let
      inherit (user.system) uid;
      gid = if user.system.gid != null then user.system.gid else uid;

      # SubUID ranges: startUid = 100000 + ((uid - 1000) * 65536)
      subUidStart = 100000 + ((uid - 1000) * 65536);

      # Check if password file exists
      passwordPath = rootPath + "/.secrets/users/${userName}/hashed-password.age";
      hasPasswordFile = builtins.pathExists passwordPath;
    in
    { config, ... }:
    {
      age.secrets = lib.mkIf hasPasswordFile {
        "user-${userName}-password" = {
          rekeyFile = passwordPath;
        };
      };

      users = {
        deterministicIds.${userName} = {
          inherit uid gid;
          subUidRanges = [
            {
              startUid = subUidStart;
              count = 65536;
            }
          ];
          subGidRanges = [
            {
              startGid = subUidStart;
              count = 65536;
            }
          ];
        };

        groups.${userName}.gid = gid;

        users.${userName} = {
          isNormalUser = true;
          home = "/home/${userName}";
          group = userName;
          openssh.authorizedKeys.keys = map (k: k.key) user.identity.sshKeys;
          extraGroups = user.system.systemGroups;
          inherit (user.system) linger;
          description = user.identity.displayName;
          hashedPasswordFile = lib.mkIf hasPasswordFile config.age.secrets."user-${userName}-password".path;
        };
      };
    };
in
{
  den.aspects.users = den.lib.perHost (
    { host }:
    let
      # Build a hostOptions-like object for resolveUsers
      hostOptions = {
        hostname = host.name;
        inherit (host) system-access-groups;
        users = host.users or { };
      };

      # Run the full ACL resolution
      resolvedUsers = resolveUsers lib canonicalUsers host.environment hostOptions groupDefs;
      enabledUsers = lib.filterAttrs (_: u: u.system.enable or false) resolvedUsers;

      # Generate NixOS config for each enabled user
      userConfigs = lib.mapAttrsToList buildUnixAccountConfig enabledUsers;
    in
    {
      nixos =
        { ... }:
        {
          imports = userConfigs;
          users.mutableUsers = false;
        };
    }
  );
}
