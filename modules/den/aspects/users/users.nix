# User provisioning for den hosts.
# Reads resolved users from host.users.enabled (computed by enrichHost)
# and generates NixOS user accounts.
{
  den,
  lib,
  rootPath,
  ...
}:
let
  # Build Unix account config for a single resolved user
  buildUnixAccountConfig =
    userName: user:
    let
      inherit (user.system) uid;
      gid = if user.system.gid != null then user.system.gid else uid;
      subUidStart = 100000 + ((uid - 1000) * 65536);
      passwordPath = rootPath + "/.secrets/users/${userName}/hashed-password.age";
      hasPasswordFile = builtins.pathExists passwordPath;
    in
    { config, ... }:
    {
      age.secrets = lib.mkIf hasPasswordFile {
        "user-${userName}-password".rekeyFile = passwordPath;
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
      userConfigs = lib.mapAttrsToList buildUnixAccountConfig host.users.enabled;
    in
    {
      nixos = {
        imports = userConfigs;
        users.mutableUsers = false;
      };
    }
  );
}
