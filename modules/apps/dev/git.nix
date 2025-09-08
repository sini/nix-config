{
  flake.modules.homeManager.git =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (lib) mkOption types;

      cfg = config.programs.git;

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

      defaultIdentity = {
        email = "jason@json64.dev";
        fullName = "Jason Bowman";
        githubUser = "sini";
        signingKey = "0xA3CDE710F034AB0B";
        conditions = [
          "hasconfig:remote.*.url:git@github.com:sini/**"
        ];
      };

      identityType = types.submodule {
        options = {
          email = mkOption {
            type = types.str;
            description = lib.mdDoc "E-mail address of the user";
          };
          fullName = mkOption {
            type = types.str;
            description = lib.mdDoc "Full name of the user";
          };
          githubUser = mkOption {
            type = types.nullOr types.str;
            description = lib.mdDoc "GitHub login of the user";
            default = null;
          };
          signingKey = mkOption {
            type = types.nullOr types.str;
            description = lib.mdDoc "GPG signing key";
            default = null;
          };
          conditions = mkOption {
            type = types.listOf types.str;
            description = lib.mdDoc "List of include conditions";
          };
        };
      };
    in
    {
      options.programs.git = {
        defaultIdentity = mkOption {
          type = types.nullOr identityType;
          description = lib.mdDoc "Default identity";
          default = defaultIdentity;
        };

        extraIdentities = mkOption {
          type = types.listOf identityType;
          description = lib.mdDoc "Extra list of identities";
          default = [ ];
        };
      };

      config = {
        programs = {
          git = {
            enable = true;
            signing.format = lib.mkForce "openpgp";
            delta = {
              enable = true;
              options = {
                light = false;
                line-numbers = true;
                navigate = true;
                side-by-side = true;
              };
            };
            extraConfig = {
              pull.rebase = true;
              commit.gpgsign = true;
              init.defaultBranch = "main";
              push.autoSetupRemote = true;

              merge.conflictstyle = "diff3";

              "url \"git@github.com:\"".pushInsteadOf = "https://github.com/";
              "url \"git@git.sr.ht:\"".pushInsteadOf = "https://git.sr.ht/";

              core.autocrlf = "input";

              # Only on WSL
              # core.fileMode = false;

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
              "result"
              ".DS_Store"
              "/.helix"
              ".flake"
              ".pkgs"

              # Non-standard
              ".aider*"
              "!.aider.conf.yml"
              "!.aiderignore"
            ];

            includes = lib.pipe ([ cfg.defaultIdentity ] ++ cfg.extraIdentities) [
              (builtins.filter (v: v != null))
              (builtins.map (
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
                builtins.map (condition: {
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
}
