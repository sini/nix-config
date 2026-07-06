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
        host,
        user,
        config,
        pkgs,
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
        # Set up a symlink from the active Bitwarden Desktop socket to the unified path.
        # This resolves differences between Flatpak installations on Linux,
        # and App Store vs DMG/Homebrew on macOS.
        home.activation.link-bitwarden-ssh-agent = config.lib.dag.entryAfter [ "writeBoundary" ] ''
          if [ -d "$HOME/.var/app/com.bitwarden.desktop/data" ]; then
            ln -sf "$HOME/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock" "$HOME/.bitwarden-ssh-agent.sock"
          elif [ -d "$HOME/Library/Containers/com.bitwarden.desktop/Data" ]; then
            ln -sf "$HOME/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock" "$HOME/.bitwarden-ssh-agent.sock"
          fi
        '';

        home.sessionVariables = {
          SSH_AUTH_SOCK = "${config.home.homeDirectory}/.bitwarden-ssh-agent.sock";
        };

        programs.rbw = {
          enable = true;
          settings = {
            email = bitwardenEmail;
            pinentry =
              if pkgs.stdenv.hostPlatform.isDarwin then
                pkgs.pinentry_mac
              else if (host.hasAspect den.aspects.roles.dev-gui) then
                pkgs.pinentry-gnome3
              else
                pkgs.pinentry-tty;
            lock_timeout = 24 * 60 * 60; # 1 day
          };
        };
      };

    # macOS launchd configuration to export SSH_AUTH_SOCK globally for the Bitwarden agent.
    homeDarwin =
      { ... }:
      {
        # Point to the unified Bitwarden socket path
        programs.ssh.settings."*".identityAgent = "~/.bitwarden-ssh-agent.sock";

        # Export SSH_AUTH_SOCK into launchd
        launchd.agents.ssh-auth-sock = {
          enable = true;
          config = {
            ProgramArguments = [
              "/bin/sh"
              "-c"
              ''/bin/launchctl setenv SSH_AUTH_SOCK "$HOME/.bitwarden-ssh-agent.sock"''
            ];
            RunAtLoad = true;
          };
        };
      };
  };
}
