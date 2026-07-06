{
  den,
  lib,
  ...
}:
{
  den.aspects.apps.dev.git = {
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
        localKeyPath = secrets.user-signing-key or "$HOME/.ssh/id_signing";

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

        git-ssh-signer = pkgs.writeShellScriptBin "git-ssh-signer" ''
          # Determine rbw socket path dynamically
          RBW_SOCKET=""
          if [ -n "''${XDG_RUNTIME_DIR:-}" ] && [ -S "''${XDG_RUNTIME_DIR}/rbw/ssh-agent-socket" ]; then
            RBW_SOCKET="''${XDG_RUNTIME_DIR}/rbw/ssh-agent-socket"
          elif command -v getconf >/dev/null 2>&1; then
            DARWIN_TEMP=$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null)
            if [ -n "$DARWIN_TEMP" ] && [ -S "$DARWIN_TEMP/rbw-$(id -u)/ssh-agent-socket" ]; then
              RBW_SOCKET="$DARWIN_TEMP/rbw-$(id -u)/ssh-agent-socket"
            fi
          fi

          # Check if Bitwarden Desktop socket is active and unlocked
          SOCKET="$HOME/.bitwarden-ssh-agent.sock"
          if [ -S "$SOCKET" ] && SSH_AUTH_SOCK="$SOCKET" ${pkgs.openssh}/bin/ssh-add -l >/dev/null 2>&1; then
            export SSH_AUTH_SOCK="$SOCKET"
            exec ${pkgs.openssh}/bin/ssh-keygen "$@"
          # Check if rbw socket is active and unlocked
          elif [ -n "$RBW_SOCKET" ] && SSH_AUTH_SOCK="$RBW_SOCKET" ${pkgs.openssh}/bin/ssh-add -l >/dev/null 2>&1; then
            export SSH_AUTH_SOCK="$RBW_SOCKET"
            exec ${pkgs.openssh}/bin/ssh-keygen "$@"
          else
            # Agent not running or locked, fall back to the decrypted agenix private key file.
            # We replace whatever key path git passed with our local agenix private key.
            args=()
            while [ $# -gt 0 ]; do
              case "$1" in
                -s)
                  args+=("-s" "${localKeyPath}")
                  shift 2
                  ;;
                *)
                  args+=("$1")
                  shift
                  ;;
              esac
            done
            exec ${pkgs.openssh}/bin/ssh-keygen "''${args[@]}"
          fi
        '';

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
          }
          // lib.optionalAttrs (signingMethod == "ssh") {
            gpg.ssh.program = "${git-ssh-signer}/bin/git-ssh-signer";
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
