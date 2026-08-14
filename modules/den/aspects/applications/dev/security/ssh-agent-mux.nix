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
    # ssh-agent-lib 0.6.0 builds on the released ssh-key 0.6.7, which still
    # rejects `Valid: forever` certificates (valid_before = u64::MAX) with
    # "invalid time" (RustCrypto/SSH#504). Until ssh-key 0.7.0 ships, the mux
    # fork's Cargo patch points ssh-agent-lib at sini/ssh-agent-lib built on
    # ssh-key 0.7.0-rc.11 (a fetched git dependency resolved by fetchCargoVendor).
    # Wrapped in a function so pipe assembly does not pre-apply the overlay.
    nixpkgs-overlays = _: [
      (final: prev: {
        ssh-agent-mux = prev.ssh-agent-mux.overrideAttrs (_old: rec {
          version = "0.2.0-unstable-2026-08-13";
          src = final.fetchFromGitHub {
            owner = "sini";
            repo = "ssh-agent-mux";
            rev = "223f6c232f07e0b573cdfc0cf54d441b8aa6a45a";
            hash = "sha256-41L3cCNwfAFhCXiLANcXcsZjXhzk07hZYYNKwPxFkd8=";
          };
          cargoDeps = final.rustPlatform.fetchCargoVendor {
            inherit src;
            name = "ssh-agent-mux-${version}-vendor";
            hash = "sha256-BJg57gXpyfD+6vTYUnmU7W8RL+JU2W1NoFpLnq4vnDw=";
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
          SIGNING_KEY_PATH="${config.age.secrets.user-signing-key.path or "$HOME/.ssh/id_signing"}"

          # Load the signing key into the standard agent before starting the mux
          if [ -f "$SIGNING_KEY_PATH" ] && [ -S "$STANDARD_SOCK" ]; then
            SSH_AUTH_SOCK="$STANDARD_SOCK" ${pkgs.openssh}/bin/ssh-add "$SIGNING_KEY_PATH" 2>/dev/null || true
          fi

          # Pass all potential sockets to the multiplexer unconditionally.
          # ssh-agent-mux gracefully ignores missing upstream sockets and will
          # automatically connect to them if they are created later (e.g. when rbw is unlocked).
          ARGS=( "-l" "$MUX_SOCK" "$STANDARD_SOCK" "$DESKTOP_SOCK" "$RBW_SOCK" )

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
        wrapper = pkgs.writeShellScript "ssh-agent-mux-start" ''
          set -euo pipefail

          DARWIN_TEMP=$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null || true)
          DARWIN_TEMP="''${DARWIN_TEMP%/}"

          MUX_SOCK="$DARWIN_TEMP/ssh-agent-mux.sock"
          STANDARD_SOCK="$DARWIN_TEMP/standard-ssh-agent.sock"
          RBW_SOCK="$DARWIN_TEMP/rbw-$(id -u)/ssh-agent-socket"
          DESKTOP_SOCK="$HOME/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock"
          SIGNING_KEY_PATH="${config.age.secrets.user-signing-key.path or "$HOME/.ssh/id_signing"}"

          # Load the signing key into the standard agent before starting the mux
          if [ -f "$SIGNING_KEY_PATH" ] && [ -S "$STANDARD_SOCK" ]; then
            SSH_AUTH_SOCK="$STANDARD_SOCK" ${pkgs.openssh}/bin/ssh-add "$SIGNING_KEY_PATH" 2>/dev/null || true
          fi

          # Pass all potential sockets to the multiplexer unconditionally.
          # ssh-agent-mux gracefully ignores missing upstream sockets and will
          # automatically connect to them if they are created later (e.g. when rbw is unlocked).
          ARGS=( "-l" "$MUX_SOCK" "$STANDARD_SOCK" "$DESKTOP_SOCK" "$RBW_SOCK" )

          exec ${pkgs.ssh-agent-mux}/bin/ssh-agent-mux "''${ARGS[@]}"
        '';
      in
      {
        home.sessionVariables = {
          SSH_AUTH_SOCK = ''$(DARWIN_TEMP=$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null); echo "$DARWIN_TEMP/ssh-agent-mux.sock")'';
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
