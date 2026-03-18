{ lib, rootPath, ... }:
{
  flake.features.users = {
    linux =
      {
        config,
        users,
        host,
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
            hostUser = host.users.${userName} or { };
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

    darwin =
      {
        environment,
        ...
      }:
      let
        # Filter for Unix account users from environment
        unixAccountUsers = lib.filterAttrs (
          _name: user: (user.enableUnixAccount or false)
        ) environment.users;

        # Build Darwin user configurations
        buildDarwinUserConfig = userName: envUser: {
          users.users.${userName} = {
            inherit (envUser) uid;
            home = "/Users/${userName}";
            description = envUser.displayName;
            openssh.authorizedKeys.keys = envUser.sshKeys;
          };

          # nix-darwin requires knownUsers for declarative user management
          users.knownUsers = [ userName ];
        };

        darwinUserConfigs = lib.mapAttrsToList buildDarwinUserConfig unixAccountUsers;
      in
      {
        imports = darwinUserConfigs;
      };
  };
}
