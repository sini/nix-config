{ lib, ... }:
let
  identityType = lib.types.submodule {
    options = {
      email = lib.mkOption {
        type = lib.types.str;
        description = "E-mail address of the user";
      };
      fullName = lib.mkOption {
        type = lib.types.str;
        description = "Full name of the user";
      };
      githubUser = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        description = "GitHub login of the user";
        default = null;
      };
      signingKey = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        description = "GPG signing key";
        default = null;
      };
      conditions = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "List of git includeIf conditions";
      };
    };
  };
in
{
  features.git = {
    requires = [
      "delta"
      "gh"
      "jujutsu"
      "lazygit"
    ];

    user-settings = {
      extraIdentities = lib.mkOption {
        type = lib.types.listOf identityType;
        default = [ ];
        description = "Additional git identities with conditional includes";
      };
    };

    home =
      {
        config,
        pkgs,
        lib,
        user,
        ...
      }:
      let
        username = config.home.username;
        userEmail = user.identity.email or "${username}@users.noreply.github.com";

        makeGitConfig =
          {
            userName,
            userEmail,
            githubUser,
            signingKey,
          }:
          pkgs.writeText "config" (
            ''
              [user]
                name = "${userName}"
                email = "${userEmail}"
                ${lib.optionalString (signingKey != null) ''
                  signingKey = "${signingKey}"
                ''}
            ''
            + lib.optionalString (githubUser != null) ''
              [github]
                user = "${githubUser}"
            ''
          );

        gpgKey = user.identity.gpgKey or null;
        defaultIdentity =
          if gpgKey != null then
            {
              email = userEmail;
              fullName = user.identity.displayName or username;
              githubUser = username;
              signingKey = gpgKey;
              conditions = [
                "hasconfig:remote.*.url:git@github.com:${username}/**"
              ];
            }
          else
            null;

        allIdentities = [ defaultIdentity ] ++ (user.settings.git.extraIdentities or [ ]);
      in
      {
        config.programs.git = {
          enable = true;
          signing = {
            signByDefault = gpgKey != null;
          }
          // lib.optionalAttrs (gpgKey != null) {
            format = "openpgp";
            key = gpgKey;
          };
          settings = {
            user.name = user.identity.displayName or username;
            user.email = userEmail;
            pull.rebase = true;
            init.defaultBranch = "main";
            push.autoSetupRemote = true;
            merge.conflictstyle = "diff3";
            "url \"git@github.com:\"".pushInsteadOf = "https://github.com/";
            core.autocrlf = "input";
            http.postBuffer = "524288000";
          };

          ignores = [
            ".direnv"
            "result"
            "result-*"
            "#*"
            ".git-bak*"
            "*~"
            "*.swp"
            ".DS_Store"
            "/.helix"
            ".flake"
            ".pkgs"
            ".aider*"
            "!.aider.conf.yml"
            "!.aiderignore"
          ];

          includes = lib.pipe allIdentities [
            (builtins.filter (v: v != null))
            (map (
              {
                email,
                fullName,
                githubUser,
                signingKey,
                conditions,
              }:
              let
                configFile = makeGitConfig {
                  inherit githubUser signingKey;
                  userName = fullName;
                  userEmail = email;
                };
              in
              map (condition: {
                path = configFile;
                inherit condition;
              }) conditions
            ))
            lib.flatten
          ];
        };
      };
  };
}
