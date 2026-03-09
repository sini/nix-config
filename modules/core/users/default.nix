{ lib, rootPath, ... }:
{
  flake.features.users.nixos =
    {
      config,
      users,
      hostOptions,
      environment,
      ...
    }:
    let
      # Users are already filtered in specialArgs (from environment.users)
      enabledUsers = builtins.attrNames users;

      # Filter for Unix account users from environment
      unixAccountUsers = lib.filterAttrs (
        _name: user: (user.enableUnixAccount or false)
      ) environment.users;

      # Function to build merged user configuration from all sources
      buildUserConfig =
        userName:
        let
          # Get user from environment
          envUser = environment.users.${userName} or { };
          envConfig = envUser.configuration or { };

          # Get user from host
          hostUser = hostOptions.users.${userName} or { };
          hostConfig = hostUser.configuration or { };

          # Merge all configurations - later configs can override earlier ones
          mergedConfig = {
            imports = [
              envConfig
              hostConfig
            ];
          };
        in
        mergedConfig;

      userConfigs = map buildUserConfig enabledUsers;

      # Build Unix account configurations
      buildUnixAccountConfig =
        userName: envUser:
        let
          inherit (envUser) uid;
          gid = if envUser.gid != null then envUser.gid else uid;

          # Calculate subUid/subGid ranges: startUid = 100000 + ((uid - 1000) * 65536)
          subUidStart = 100000 + ((uid - 1000) * 65536);
          subGidStart = subUidStart;

          # Check if password file exists
          passwordPath = rootPath + "/.secrets/users/${userName}/hashed-password.age";
          hasPasswordFile = builtins.pathExists passwordPath;
        in
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
                  startGid = subGidStart;
                  count = 65536;
                }
              ];
            };

            groups.${userName}.gid = gid;

            users.${userName} = {
              isNormalUser = true;
              home = "/home/${userName}";
              group = userName;
              openssh.authorizedKeys.keys = envUser.sshKeys;
              extraGroups = envUser.systemGroups;
              inherit (envUser) linger;
              description = envUser.displayName;
              hashedPasswordFile = lib.mkIf hasPasswordFile config.age.secrets."user-${userName}-password".path;
            };
          };
        };

      unixAccountConfigs = lib.mapAttrsToList buildUnixAccountConfig unixAccountUsers;
    in
    {
      imports = userConfigs ++ unixAccountConfigs;
      users.mutableUsers = false;
    };
}
