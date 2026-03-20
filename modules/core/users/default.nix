{ lib, rootPath, ... }:
{
  features.users = {
    linux =
      {
        config,
        users,
        ...
      }:
      let
        enabledUsers = lib.filterAttrs (_: u: u.system.enable or false) users;

        # Build Unix account configurations
        buildUnixAccountConfig =
          userName: user:
          let
            inherit (user.system) uid;
            gid = if user.system.gid != null then user.system.gid else uid;

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
                openssh.authorizedKeys.keys = user.identity.sshKeys;
                extraGroups = user.system.systemGroups;
                inherit (user.system) linger;
                description = user.identity.displayName;
                hashedPasswordFile = lib.mkIf hasPasswordFile config.age.secrets."user-${userName}-password".path;
              };
            };
          };

        unixAccountConfigs = lib.mapAttrsToList buildUnixAccountConfig enabledUsers;
      in
      {
        imports = unixAccountConfigs;
        users.mutableUsers = false;
      };

    darwin =
      {
        users,
        pkgs,
        ...
      }:
      let
        enabledUsers = lib.filterAttrs (_: u: u.system.enable or false) users;

        # Build Darwin user configurations
        buildDarwinUserConfig =
          userName: user:
          let
            isWheel = builtins.elem "wheel" user.system.systemGroups;
          in
          {
            users = {
              # nix-darwin requires knownUsers for declarative user management
              knownUsers = [ userName ];
              users = {
                ${userName} = {
                  inherit (user.system) uid;
                  home = "/Users/${userName}";
                  createHome = true;
                  description = user.identity.displayName;
                  isHidden = false;
                  openssh.authorizedKeys.keys = user.identity.sshKeys;
                  shell = pkgs.zsh;
                };

                # Add SSH authorized keys to root for wheel users (needed for colmena deployment)
                root.openssh.authorizedKeys.keys = lib.mkIf isWheel user.identity.sshKeys;
              };
            };
          };

        darwinUserConfigs = lib.mapAttrsToList buildDarwinUserConfig enabledUsers;
      in
      {
        imports = darwinUserConfigs;
      };
  };
}
