{ ... }:
{
  den.aspects.applications.dev.security.ssh-agent-mux = {
    # Build ssh-agent-mux from the sini fork. It bumps ssh-agent-lib 0.5.1 ->
    # 0.6.0 for the `PublicCredential` (Key | Cert) type, so an SSH *certificate*
    # in an upstream agent — e.g. the opkssh OIDC cert loaded into the standard
    # agent — round-trips through the mux instead of decoding to a lossy opaque
    # key and re-serializing a truncated identity list, which made `ssh-add -l`
    # fail with "incomplete message" and dropped every other agent's keys
    # (overhacked/ssh-agent-mux#56). The fork is branched off upstream main, so it
    # also carries the merged list-errors tolerance (#94): a misbehaving upstream
    # (rbw mid-unlock) is skipped instead of taking down the whole list.
    #
    # This builds on the RELEASED ssh-key 0.6.7 (no ssh-key 0.7 fork): our opkssh
    # fork now mints certificates with a real valid_before (= the ID Token exp),
    # which ssh-key 0.6.7 parses fine. Only the old `Valid: forever` certs
    # (valid_before = u64::MAX) needed ssh-key 0.7 (RustCrypto/SSH#504).
    # Wrapped in a function so pipe assembly does not pre-apply the overlay.
    nixpkgs-overlays = _: [
      (final: prev: {
        ssh-agent-mux = prev.ssh-agent-mux.overrideAttrs (_old: rec {
          version = "0.2.0-unstable-2026-08-13";
          src = final.fetchFromGitHub {
            owner = "sini";
            repo = "ssh-agent-mux";
            rev = "8c47a16b2878de0525bbe564a30779ece40694f1";
            hash = "sha256-YnjFMfHlIRN6vfsXiDf+cA9/0vZ132mtIuCvLB/HLHg=";
          };
          cargoDeps = final.rustPlatform.fetchCargoVendor {
            inherit src;
            name = "ssh-agent-mux-${version}-vendor";
            hash = "sha256-UsJUGxs7tn9wGtmjjPIHIO7dy6R5HXhlQ9eg8A3gRbw=";
          };
          patches = [ ];
        });
      })
    ];

    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.ssh-agent-mux ];
      };

    homeLinux =
      { pkgs, config, ... }:
      let
        # Load the git signing key into the standard agent once its socket is up
        # and the agenix secret is decrypted. Runs as standard-ssh-agent's
        # ExecStartPost, so it reloads whenever that agent (re)starts and does not
        # race the mux the way loading it from the mux wrapper did (After= only
        # guarantees the unit started, not that ssh-agent bound its socket).
        signingKeyLoader = pkgs.writeShellScript "standard-ssh-agent-load-key" ''
          set -uo pipefail
          RUNTIME="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
          SOCK="$RUNTIME/standard-ssh-agent.sock"
          KEY="${config.age.secrets.user-signing-key.path or "$HOME/.ssh/id_signing"}"
          for _ in $(seq 1 100); do
            { [ -S "$SOCK" ] && [ -f "$KEY" ]; } && break
            sleep 0.1
          done
          [ -S "$SOCK" ] && [ -f "$KEY" ] \
            && SSH_AUTH_SOCK="$SOCK" ${pkgs.openssh}/bin/ssh-add "$KEY" 2>/dev/null
          exit 0
        '';
        wrapper = pkgs.writeShellScript "ssh-agent-mux-start" ''
          set -euo pipefail

          # Ensure XDG_RUNTIME_DIR is set
          if [ -z "''${XDG_RUNTIME_DIR:-}" ]; then
            export XDG_RUNTIME_DIR="/run/user/$(id -u)"
          fi

          MUX_SOCK="$XDG_RUNTIME_DIR/ssh-agent-mux.sock"
          STANDARD_SOCK="$XDG_RUNTIME_DIR/standard-ssh-agent.sock"
          RBW_SOCK="$XDG_RUNTIME_DIR/rbw/ssh-agent-socket"
          DESKTOP_SOCK="$HOME/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock"
          # Asked of gpgconf rather than hardcoded: the path is derived from a
          # hash of the gnupg homedir, so it moves if programs.gpg.homedir does.
          # Resolvable whether or not the agent has started.
          GPG_SOCK="$(${pkgs.gnupg}/bin/gpgconf --list-dirs agent-ssh-socket 2>/dev/null \
            || echo "$XDG_RUNTIME_DIR/gnupg/S.gpg-agent.ssh")"

          # (The signing key is loaded into the standard agent by that agent's
          # own ExecStartPost, not here.)

          # Pass all potential sockets to the multiplexer unconditionally.
          # ssh-agent-mux gracefully ignores missing upstream sockets and will
          # automatically connect to them if they are created later (e.g. when rbw is unlocked).
          ARGS=( "-l" "$MUX_SOCK" "$STANDARD_SOCK" "$DESKTOP_SOCK" "$RBW_SOCK" "$GPG_SOCK" )

          exec ${pkgs.ssh-agent-mux}/bin/ssh-agent-mux "''${ARGS[@]}"
        '';
      in
      {
        home.sessionVariables = {
          SSH_AUTH_SOCK = "\${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ssh-agent-mux.sock";
        };

        systemd.user.services.standard-ssh-agent = {
          Unit = {
            Description = "Standard SSH Agent Backend";
          };
          Install = {
            WantedBy = [ "default.target" ];
          };
          Service = {
            ExecStart = "${pkgs.openssh}/bin/ssh-agent -D -a %t/standard-ssh-agent.sock";
            ExecStartPost = "${signingKeyLoader}";
            Restart = "always";
          };
        };

        systemd.user.services.ssh-agent-mux = {
          Unit = {
            Description = "SSH Agent Multiplexer";
            After = [ "standard-ssh-agent.service" ];
          };
          Install = {
            WantedBy = [ "default.target" ];
          };
          Service = {
            ExecStart = "${wrapper}";
            Restart = "always";
          };
        };
      };

    homeDarwin =
      { pkgs, config, ... }:
      let
        # Load the git signing key into the standard agent once its socket is up
        # and the agenix secret is decrypted, from a dedicated launchd agent
        # rather than the mux wrapper (which raced the standard socket at login).
        signingKeyLoader = pkgs.writeShellScript "standard-ssh-agent-load-key" ''
          set -uo pipefail
          DARWIN_TEMP=$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null || true)
          DARWIN_TEMP="''${DARWIN_TEMP%/}"
          SOCK="$DARWIN_TEMP/standard-ssh-agent.sock"
          KEY="${config.age.secrets.user-signing-key.path or "$HOME/.ssh/id_signing"}"
          for _ in $(seq 1 100); do
            { [ -S "$SOCK" ] && [ -f "$KEY" ]; } && break
            sleep 0.1
          done
          [ -S "$SOCK" ] && [ -f "$KEY" ] \
            && SSH_AUTH_SOCK="$SOCK" ${pkgs.openssh}/bin/ssh-add "$KEY" 2>/dev/null
          exit 0
        '';
        wrapper = pkgs.writeShellScript "ssh-agent-mux-start" ''
          set -euo pipefail

          DARWIN_TEMP=$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null || true)
          DARWIN_TEMP="''${DARWIN_TEMP%/}"

          MUX_SOCK="$DARWIN_TEMP/ssh-agent-mux.sock"
          STANDARD_SOCK="$DARWIN_TEMP/standard-ssh-agent.sock"
          RBW_SOCK="$DARWIN_TEMP/rbw-$(id -u)/ssh-agent-socket"
          DESKTOP_SOCK="$HOME/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock"
          GPG_SOCK="$(${pkgs.gnupg}/bin/gpgconf --list-dirs agent-ssh-socket 2>/dev/null \
            || echo "$HOME/.gnupg/S.gpg-agent.ssh")"

          # (The signing key is loaded into the standard agent by the
          # standard-ssh-agent-load-key launchd agent, not here.)

          # Pass all potential sockets to the multiplexer unconditionally.
          # ssh-agent-mux gracefully ignores missing upstream sockets and will
          # automatically connect to them if they are created later (e.g. when rbw is unlocked).
          ARGS=( "-l" "$MUX_SOCK" "$STANDARD_SOCK" "$DESKTOP_SOCK" "$RBW_SOCK" "$GPG_SOCK" )

          exec ${pkgs.ssh-agent-mux}/bin/ssh-agent-mux "''${ARGS[@]}"
        '';
      in
      {
        home.sessionVariables = {
          SSH_AUTH_SOCK = ''$(DARWIN_TEMP=$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null); echo "$DARWIN_TEMP/ssh-agent-mux.sock")'';
        };

        # Export the mux socket into the GUI login session, so it reaches apps
        # and scripts rather than only interactive shells. This lived in the gpg
        # aspect and pointed at gpg's own socket; it belongs with whichever agent
        # actually fronts ssh, which is now the mux.
        launchd.agents.ssh-auth-sock = {
          enable = true;
          config = {
            ProgramArguments = [
              "/bin/sh"
              "-c"
              ''DARWIN_TEMP=$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null); /bin/launchctl setenv SSH_AUTH_SOCK "$DARWIN_TEMP/ssh-agent-mux.sock"''
            ];
            RunAtLoad = true;
          };
        };

        launchd.agents.standard-ssh-agent = {
          enable = true;
          config = {
            ProgramArguments = [
              "/bin/sh"
              "-c"
              ''DARWIN_TEMP=$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null); exec ${pkgs.openssh}/bin/ssh-agent -D -a "$DARWIN_TEMP/standard-ssh-agent.sock"''
            ];
            RunAtLoad = true;
            KeepAlive = true;
          };
        };

        launchd.agents.standard-ssh-agent-load-key = {
          enable = true;
          config = {
            ProgramArguments = [ "${signingKeyLoader}" ];
            RunAtLoad = true;
          };
        };

        launchd.agents.ssh-agent-mux = {
          enable = true;
          config = {
            ProgramArguments = [ "${wrapper}" ];
            RunAtLoad = true;
            KeepAlive = true;
          };
        };

        launchd.agents.ssh-auth-sock-mux = {
          enable = true;
          config = {
            ProgramArguments = [
              "/bin/sh"
              "-c"
              ''/bin/launchctl setenv SSH_AUTH_SOCK "$(/bin/sh -c 'DARWIN_TEMP=$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null); echo "$DARWIN_TEMP/ssh-agent-mux.sock"')"''
            ];
            RunAtLoad = true;
          };
        };
      };
  };
}
