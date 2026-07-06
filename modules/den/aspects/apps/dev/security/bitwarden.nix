{ den, lib, ... }:
{
  den.aspects.apps.dev.security.bitwarden = {
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
      { pkgs, host, ... }:
      {
        programs.rbw.settings.pinentry =
          if (host.hasAspect den.aspects.roles.dev-gui) then pkgs.pinentry-gnome3 else pkgs.pinentry-tty;

        home.sessionVariables = {
          # Export SSH_AUTH_SOCK directly, resolving dynamically to either Desktop (Flatpak) or rbw socket.
          # We escape the dollar sign so it is evaluated at shell startup time in user environments.
          SSH_AUTH_SOCK = ''
            $(
              if [ -S "$HOME/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock" ]; then
                echo "$HOME/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock"
              else
                echo "''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/rbw/ssh-agent-socket"
              fi
            )'';
        };
      };

    # macOS launchd and ssh configuration to export SSH_AUTH_SOCK globally for the Bitwarden agent.
    homeDarwin =
      { pkgs, ... }:
      {
        programs.rbw.settings.pinentry = pkgs.pinentry_mac;

        # Point to the active Bitwarden Desktop socket path on macOS
        programs.ssh.settings."*".identityAgent =
          "~/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock";

        home.sessionVariables = {
          SSH_AUTH_SOCK = ''
            $(
              if [ -S "$HOME/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock" ]; then
                echo "$HOME/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock"
              else
                DARWIN_TEMP=$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null)
                echo "$DARWIN_TEMP/rbw-$(id -u)/ssh-agent-socket"
              fi
            )'';
        };

        # Export SSH_AUTH_SOCK into launchd
        launchd.agents.ssh-auth-sock = {
          enable = true;
          config = {
            ProgramArguments = [
              "/bin/sh"
              "-c"
              ''/bin/launchctl setenv SSH_AUTH_SOCK "$(/bin/sh -c 'if [ -S "$HOME/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock" ]; then echo "$HOME/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock"; else DARWIN_TEMP=$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null); echo "$DARWIN_TEMP/rbw-$(id -u)/ssh-agent-socket"; fi')"''
            ];
            RunAtLoad = true;
          };
        };
      };
  };
}
