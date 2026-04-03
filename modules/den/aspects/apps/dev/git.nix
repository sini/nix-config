{ den, ... }:
{
  # NOTE: git.user-settings.extraIdentities is not yet migrated to den schema.
  # The `requires` for delta, gh, jujutsu, lazygit are handled by host aspect includes.
  den.aspects.git = den.lib.perUser {
    homeManager =
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
