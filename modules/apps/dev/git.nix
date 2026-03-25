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
        environment,
        ...
      }:
      let
        username = config.home.username;

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

        # Build default identity from resolved user
        gpgKey = user.identity.gpgKey or null;
        defaultIdentity =
          if gpgKey != null then
            {
              email =
                if user.identity.email or null != null then
                  user.identity.email
                else
                  "${username}@${environment.email.domain}";
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
        config = {
          programs = {
            delta = {
              enable = true;
              options = {
                light = false;
                line-numbers = true;
                navigate = true;
                side-by-side = true;
              };
            };
            git = {
              enable = true;
              signing.format = lib.mkForce "openpgp";
              settings = {
                pull.rebase = true;
                commit.gpgsign = true;
                init.defaultBranch = "main";
                push.autoSetupRemote = true;
                merge.conflictstyle = "diff3";
                "url \"git@github.com:\"".pushInsteadOf = "https://github.com/";
                core.autocrlf = "input";

                # Increase the size of post buffers to prevent hung ups of git-push.
                # https://stackoverflow.com/questions/6842687/the-remote-end-hung-up-unexpectedly-while-git-cloning#6849424
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

                # Non-standard
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

            gh = {
              enable = true;

              settings = {
                git_protocol = "ssh";
              };
            };

            jujutsu = {
              enable = true;
            };

            lazygit = {
              enable = true;
              # https://github.com/jesseduffield/lazygit/blob/master/docs/Config.md
              settings = {
                gui = {
                  # showListFooter = false;
                  # showRandomTip = false;
                  # showCommandLog = false;
                  # showBottomLine = false;
                  nerdFontsVersion = "3";
                };

                git = {
                  # Improves performance
                  overrideGpg = true;

                  # https://github.com/jesseduffield/lazygit/issues/2875#issuecomment-1665376437
                  log.order = "default";
                  parseEmoji = true;
                  commit.signOff = true;
                  fetchAll = false;
                };
              };
            };
          };
          home.shellAliases = {
            lg = "lazygit";
          };
        };
      };
  };
}
