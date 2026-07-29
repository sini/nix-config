{ den, lib, ... }:
{
  den.aspects.applications.dev.security.gpg = {
    settings = {
      enableSshAgent = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to use gpg-agent as the SSH agent";
      };
    };

    nixos = {
      services.pcscd.enable = true;
      hardware.gpgSmartcards.enable = true;
    };

    homeManager =
      { user, ... }:
      let
        enableSshAgent = user.settings.gpg.enableSshAgent or true;
      in
      {
        programs.gpg = {
          enable = true;

          scdaemonSettings = {
            disable-ccid = true;
          };

          settings = {
            personal-cipher-preferences = "AES256 AES192 AES";
            personal-digest-preferences = "SHA512 SHA384 SHA256";
            personal-compress-preferences = "ZLIB BZIP2 ZIP Uncompressed";
            default-preference-list = "SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed";
            cert-digest-algo = "SHA512";
            s2k-digest-algo = "SHA512";
            s2k-cipher-algo = "AES256";
            charset = "utf-8";
            fixed-list-mode = true;
            no-comments = true;
            no-emit-version = true;
            keyid-format = "0xlong";
            list-options = "show-uid-validity";
            verify-options = "show-uid-validity";
            with-fingerprint = true;
            require-cross-certification = true;
            no-symkey-cache = true;
            use-agent = true;
            throw-keyids = true;
          };
        };

        services = {
          gpg-agent = {
            enable = true;
            enableExtraSocket = true;
            enableSshSupport = enableSshAgent;

            enableBashIntegration = true;
            enableZshIntegration = true;
            enableFishIntegration = true;
            enableNushellIntegration = true;

            defaultCacheTtl = 43200;
            defaultCacheTtlSsh = 43200;
            maxCacheTtl = 86400;
            maxCacheTtlSsh = 86400;

            extraConfig = ''
              ttyname $GPG_TTY
            '';
          };
        };
      };

    homeLinux =
      { pkgs, host, ... }:
      {
        services.gpg-agent.pinentry.package =
          if (host.hasAspect den.aspects.roles.workstation) then pkgs.pinentry-gnome3 else pkgs.pinentry-tty;
      };

    homeDarwin =
      { pkgs, user, ... }:
      let
        enableSshAgent = user.settings.gpg.enableSshAgent or true;
      in
      {
        services.gpg-agent.pinentry.package = pkgs.pinentry_mac;
      }
      // lib.optionalAttrs enableSshAgent {
        # `ssh` itself: point straight at gpg-agent's ssh socket.
        programs.ssh.settings."*".identityAgent = "~/.gnupg/S.gpg-agent.ssh";

        # Everything else (ssh-add, GUI apps, scripts): export SSH_AUTH_SOCK into
        # the GUI launchd session at login so it's not limited to interactive
        # shells. gpgconf resolves the socket path regardless of whether the agent
        # has started yet.
        launchd.agents.ssh-auth-sock = {
          enable = true;
          config = {
            ProgramArguments = [
              "/bin/sh"
              "-c"
              ''/bin/launchctl setenv SSH_AUTH_SOCK "$(${pkgs.gnupg}/bin/gpgconf --list-dirs agent-ssh-socket)"''
            ];
            RunAtLoad = true;
          };
        };
      };

    persistHome = {
      directories = [
        {
          directory = ".gnupg";
          mode = "0700";
        }
      ];
    };
  };
}
