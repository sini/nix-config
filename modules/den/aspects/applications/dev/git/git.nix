{
  den,
  lib,
  ...
}:
{
  den.aspects.applications.dev.git = {
    settings = {
      signing = {
        method = lib.mkOption {
          type = lib.types.enum [
            "none"
            "ssh"
            "openpgp"
          ];
          default = "none";
          description = "Git commit signing method";
        };
      };
    };

    homeManager =
      {
        lib,
        pkgs,
        user,
        secrets,
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
            signingMethod,
          }:
          pkgs.writeText "config" (
            ''
              [user]
                name = "${userName}"
                email = "${userEmail}"
            ''
            + lib.optionalString (signingKey != null) ''
              signingKey = "${signingKey}"
            ''
            + lib.optionalString (githubUser != null) ''
              [github]
                user = "${githubUser}"
            ''
          );

        signingMethod = user.settings.git.signing.method or "none";
        globalSigningKeyObj = lib.findFirst (k: k.tag == "global-signing") null (
          user.identity.sshKeys or [ ]
        );
        signingKey = if globalSigningKeyObj != null then globalSigningKeyObj.key else null;

        defaultIdentity = {
          email = userEmail;
          fullName = user.identity.displayName or user.name;
          githubUser = user.name;
          signingKey =
            if signingMethod == "ssh" then
              signingKey
            else if signingMethod == "openpgp" then
              user.identity.gpgKey or null
            else
              null;
          conditions = [
            "hasconfig:remote.*.url:git@github.com:${user.name}/**"
          ];
        };

        allIdentities = [ defaultIdentity ] ++ (user.settings.git.extraIdentities or [ ]);

      in
      {
        assertions = [
          {
            assertion = (signingMethod == "ssh") -> (signingKey != null);
            message = "Git signing method is set to 'ssh', but the user signing key has not been generated yet. Run 'nix run .#agenix-rekey' to generate it.";
          }
        ];

        programs.git = {
          enable = true;
          lfs.enable = true;
          signing = {
            signByDefault = signingMethod != "none";
          }
          // lib.optionalAttrs (signingMethod == "openpgp") {
            format = "openpgp";
            key = user.identity.gpgKey or null;
          }
          // lib.optionalAttrs (signingMethod == "ssh") {
            format = "ssh";
            key = signingKey;
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
                  inherit githubUser signingKey signingMethod;
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
