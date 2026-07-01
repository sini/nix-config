{
  den.aspects.apps.dev.git = {
    homeManager =
      {
        lib,
        pkgs,
        user,
        ...
      }:
      let
        userEmail = user.identity.email or "${user.name}@users.noreply.github.com";

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
              fullName = user.identity.displayName or user.name;
              githubUser = user.name;
              signingKey = gpgKey;
              conditions = [
                "hasconfig:remote.*.url:git@github.com:${user.name}/**"
              ];
            }
          else
            null;

        allIdentities = [ defaultIdentity ] ++ (user.settings.git.extraIdentities or [ ]);
      in
      {
        programs.git = {
          enable = true;
          lfs.enable = true;
          signing = {
            signByDefault = gpgKey != null;
          }
          // lib.optionalAttrs (gpgKey != null) {
            format = "openpgp";
            key = gpgKey;
          };

          settings = {
            user.name = user.identity.displayName or user.name;
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
            ".worktrees"
            ".pre-commit-config.yaml"
            ".claude"
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
