{ den, lib, ... }:
{
  den.aspects.applications.dev.security.bitwarden = {
    settings = {
      email = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Override email address for Bitwarden rbw configuration";
      };
    };

    homeManager =
      {
        user,
        ...
      }:
      let
        bitwardenEmail =
          let
            override = user.settings.bitwarden.email or null;
          in
          if override != null then override else (user.identity.email or null);
      in
      {
        programs.rbw = {
          enable = true;
          settings = {
            email = bitwardenEmail;
            lock_timeout = 24 * 60 * 60; # 1 day
          };
        };
      };

    # Linux-specific home manager overrides
    homeLinux =
      {
        config,
        pkgs,
        host,
        ...
      }:
      {
        home.packages = [
          pkgs.libsecret

          # Store the master password in the login keyring, but only once it is
          # proven to open the vault. Writing it unverified is worse than not
          # writing it: the pinentry below would then hand rbw the same wrong
          # password on all three of its attempts, and every later unlock would
          # fail with nothing on screen pointing at the keyring.
          (pkgs.writeShellApplication {
            name = "rbw-remember";
            runtimeInputs = [
              pkgs.libsecret
              config.programs.rbw.package
            ];
            text = ''
              export DBUS_SESSION_BUS_ADDRESS="''${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"

              # Held so a failed check can put back a working entry rather than
              # leaving the host worse off than before it ran.
              previous=$(secret-tool lookup service rbw 2>/dev/null || true)

              echo "Enter the Bitwarden master password (stored in the login keyring):"
              secret-tool store --label='rbw master password' service rbw

              # An already-unlocked vault makes `rbw unlock` return success
              # without ever calling pinentry, which would "verify" nothing.
              rbw lock >/dev/null 2>&1 || true

              if rbw unlock; then
                echo "verified: the vault unlocks from the keyring entry"
              else
                if [ -n "$previous" ]; then
                  # printf, not echo: a piped secret keeps its trailing newline.
                  printf '%s' "$previous" | secret-tool store --label='rbw master password' service rbw
                  echo "verification failed - restored the previous keyring entry" >&2
                else
                  secret-tool clear service rbw >/dev/null 2>&1 || true
                  echo "verification failed - keyring entry removed, rbw will prompt as before" >&2
                fi
                exit 1
              fi
            '';
          })
        ];

        # rbw-agent's pinentry. Serves the master password from the login
        # keyring, which PAM unlocks at graphical login (desktop/gdm.nix and
        # desktop/xdg-portal.nix already wire pam_gnome_keyring), so the vault
        # unlocks with no prompt. It also makes unlocking work from contexts
        # with no display at all — an rbw-agent spawned by a systemd service
        # otherwise dies trying to open a graphical pinentry. Falls back to the
        # interactive pinentry when the keyring holds no entry, which is why the
        # lookup happens before a single byte of the Assuan protocol is read.
        #
        # One-time setup per host: run `rbw-remember` (below), which stores the
        # password only after confirming it actually opens the vault.
        #
        # Note the master password now lives in the login keyring, i.e. behind
        # the login password — the same trust model as the SSH keys gcr already
        # holds there, but it does mean vault-at-rest security is now login
        # password strength.
        programs.rbw.settings.pinentry = pkgs.writeShellScriptBin "pinentry-rbw" ''
          # glib's bus fallback covers this, but only when XDG_RUNTIME_DIR is
          # set; pin the address so keyring lookups also work from odd contexts.
          export DBUS_SESSION_BUS_ADDRESS="''${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(${pkgs.coreutils}/bin/id -u)/bus}"

          if password=$(${pkgs.libsecret}/bin/secret-tool lookup service rbw) \
            && [ -n "$password" ]; then
            # Assuan wants %, CR and LF percent-escaped. secret-tool store reads
            # one line, so % is the only one that can survive the round-trip.
            escaped=''${password//%/%25}
            printf 'OK pinentry-rbw ready\n'
            while IFS=' ' read -r command _; do
              case $command in
                GETPIN) printf 'D %s\nOK\n' "$escaped" ;;
                BYE) printf 'OK\n'; exit 0 ;;
                *) printf 'OK\n' ;;
              esac
            done
          else
            exec ${
              lib.getExe (
                if (host.hasAspect den.aspects.roles.dev-gui) then pkgs.pinentry-gnome3 else pkgs.pinentry-tty
              )
            } "$@"
          fi
        '';

        # Start the agent at graphical login, still LOCKED — unlocking stays
        # lazy. rbw's ssh-agent calls unlock_state() from both request_identities
        # and sign, and unlock_state runs pinentry when the vault needs it, so
        # the master password is asked for only when something actually reaches
        # into the vault. Nothing is cached anywhere.
        #
        # A unit is needed because rbw-agent is otherwise spawned on demand by
        # the rbw CLI, and SshAgent::run binds the ssh-agent socket when the
        # *agent starts*, not when the vault unlocks. With no agent there is no
        # socket, so ssh-agent-mux has no rbw upstream to attach to until some
        # unrelated rbw command happens to run.
        #
        # graphical-session.target rather than default.target: an unlock
        # triggered through the ssh agent has no rbw client to supply an
        # environment, so pinentry inherits the agent's own, and pinentry-gnome3
        # needs the session's display and bus to draw a prompt. On a headless
        # host the target never activates and this is inert.
        # Two units, because the agent and the unlock have different scopes.
        #
        # The agent is not graphical: on any host its ssh-agent socket is what
        # ssh-agent-mux attaches to, so it belongs on default.target. It is
        # needed at all because rbw-agent is otherwise spawned on demand by the
        # rbw CLI, and SshAgent::run binds that socket when the *agent starts*,
        # not when the vault unlocks — no agent, no socket to attach to.
        systemd.user.services.rbw-agent =
          let
            # An agent the rbw CLI spawned on demand holds an exclusive flock on
            # the pidfile and outlives the session that created it, because it
            # double-forks out of any cgroup. --no-daemonize has no graceful
            # "already running" path — that exit-23 branch exists only in the
            # daemonizing arm — so it just fails to take the lock and exits 1,
            # which Restart turns into a loop. Evict the squatter first, then
            # wait for the lock to actually clear: quit only asks it to leave.
            claimAgent = pkgs.writeShellScript "rbw-agent-claim" ''
              ${config.programs.rbw.package}/bin/rbw stop-agent 2>/dev/null || true
              pidfile="''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}/rbw/pidfile"
              for _ in $(${pkgs.coreutils}/bin/seq 50); do
                ${pkgs.util-linux}/bin/flock -n "$pidfile" true 2>/dev/null && exit 0
                ${pkgs.coreutils}/bin/sleep 0.1
              done
            '';
          in
          {
            Unit = {
              Description = "rbw agent (Bitwarden vault and ssh-agent backend)";
              After = [ "default.target" ];
              # Every activation evicts and restarts the agent, which drops the
              # decrypted vault with it. Without this the unlock unit stays
              # active (exited) from an earlier run and never fires again, so a
              # switch silently leaves the vault locked and nothing prompts.
              Wants = [ "rbw-unlock.service" ];
              # Without a limit that bites, a permanently unavailable lock just
              # restarts every 5s forever and the unit never reports failed.
              StartLimitIntervalSec = 120;
              StartLimitBurst = 5;
            };
            Service = {
              # --no-daemonize keeps it in the foreground so Type=simple can
              # track the real process rather than a daemonized orphan.
              Type = "simple";
              ExecStartPre = "-${claimAgent}";
              ExecStart = "${config.programs.rbw.package}/bin/rbw-agent --no-daemonize";
              Restart = "on-failure";
              RestartSec = 5;
            };
            Install.WantedBy = [ "default.target" ];
          };

        # The unlock is graphical: pinentry-gnome3 needs the session's display
        # and bus, and those only reach the user manager once the graphical
        # session imports them — after default.target, which is why this cannot
        # ride along with the agent. On a headless host the target never
        # activates and this is simply inert (pinentry-tty there has no terminal
        # to prompt on at login anyway).
        #
        # Kept separate from the agent rather than folded in as ExecStartPost so
        # that a dismissed or mistyped prompt fails only this unit. The vault
        # then stays locked and rbw's own lazy path prompts on next use; the
        # agent is never at risk.
        systemd.user.services.rbw-unlock =
          let
            # After= orders against the agent's *start*, which under Type=simple
            # is the fork, not the socket bind. rbw's ensure_agent() reacts to a
            # missing socket by spawning an agent that immediately exits 23 on
            # the pidfile lock, then rechecks and gives up — so without this wait
            # the unlock just quietly does nothing.
            unlockAtLogin = pkgs.writeShellScript "rbw-unlock-at-login" ''
              # The agent lives on default.target and so can restart before the
              # session has a display. With a keyring entry that does not matter,
              # since the lookup only needs the bus; without one there is nothing
              # to prompt on, and leaving the vault locked beats a failed unit.
              if [ -z "''${WAYLAND_DISPLAY:-}''${DISPLAY:-}" ] \
                && ! ${pkgs.libsecret}/bin/secret-tool lookup service rbw >/dev/null 2>&1; then
                exit 0
              fi

              sock="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/rbw/socket"
              for _ in $(${pkgs.coreutils}/bin/seq 100); do
                [ -S "$sock" ] && break
                ${pkgs.coreutils}/bin/sleep 0.1
              done
              exec ${config.programs.rbw.package}/bin/rbw unlock
            '';
          in
          {
            Unit = {
              Description = "Unlock the rbw vault at graphical login";
              After = [
                "graphical-session.target"
                "rbw-agent.service"
              ];
              Wants = [ "rbw-agent.service" ];
              # PartOf the agent as well as the session: RemainAfterExit keeps
              # this unit active for the life of one agent, and it has to be
              # stopped when that agent goes away before it can run for the next.
              PartOf = [
                "graphical-session.target"
                "rbw-agent.service"
              ];
            };
            Service = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = unlockAtLogin;
              # pinentry blocks until answered, and the default 90s start
              # timeout would kill the prompt out from under you.
              TimeoutStartSec = "infinity";
            };
            Install.WantedBy = [ "graphical-session.target" ];
          };
      };

    # macOS launchd and ssh configuration to export SSH_AUTH_SOCK globally for the Bitwarden agent.
    homeDarwin =
      { pkgs, ... }:
      {
        programs.rbw.settings.pinentry = pkgs.pinentry_mac;
      };
  };
}
