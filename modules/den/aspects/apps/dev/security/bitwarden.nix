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
      };

    # macOS launchd and ssh configuration to export SSH_AUTH_SOCK globally for the Bitwarden agent.
    homeDarwin =
      { pkgs, ... }:
      {
        programs.rbw.settings.pinentry = pkgs.pinentry_mac;
      };
  };
}
