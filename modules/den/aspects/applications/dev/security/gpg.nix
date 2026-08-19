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

            # enableSshSupport is deliberately NOT set. It bundles three things:
            # the `enable-ssh-support` config line, the listening ssh socket, and
            # a claim on sshAuthSock.initialization — home-manager's single owner
            # of SSH_AUTH_SOCK. Taking that claim would export gpg-agent's own
            # socket into every shell, putting gpg-agent in FRONT of
            # ssh-agent-mux. The first two are declared directly (below, and per
            # platform), so gpg-agent serves ssh keys as one upstream behind the
            # mux and never contends for the variable.

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
            ''
            + lib.optionalString enableSshAgent "enable-ssh-support\n";
          };
        };
      };

    homeLinux =
      {
        config,
        pkgs,
        host,
        user,
        ...
      }:
      let
        enableSshAgent = user.settings.gpg.enableSshAgent or true;
      in
      {
        services.gpg-agent.pinentry.package =
          if (host.hasAspect den.aspects.roles.workstation) then pkgs.pinentry-gnome3 else pkgs.pinentry-tty;

        # The socket half of what enableSshSupport would have configured.
        # ListenStream assumes the default gnupg homedir — home-manager derives
        # this path from a hash of a non-default one — so the assertion keeps a
        # later homedir change from silently leaving the mux with a dead
        # upstream and no gpg keys.
        assertions = lib.optionals enableSshAgent [
          {
            assertion = config.programs.gpg.homedir == "${config.home.homeDirectory}/.gnupg";
            message = "gpg: enableSshAgent assumes the default gnupg homedir; ListenStream in systemd.user.sockets.gpg-agent-ssh must be updated for ${config.programs.gpg.homedir}.";
          }
        ];

        systemd.user.sockets.gpg-agent-ssh = lib.mkIf enableSshAgent {
          Unit = {
            Description = "GnuPG cryptographic agent (ssh-agent emulation)";
            Documentation = "man:gpg-agent(1) man:ssh-add(1) man:ssh-agent(1) man:ssh(1)";
          };
          Socket = {
            ListenStream = "%t/gnupg/S.gpg-agent.ssh";
            FileDescriptorName = "ssh";
            Service = "gpg-agent.service";
            SocketMode = "0600";
            DirectoryMode = "0700";
          };
          Install.WantedBy = [ "sockets.target" ];
        };
      };

    homeDarwin =
      {
        config,
        pkgs,
        user,
        ...
      }:
      let
        enableSshAgent = user.settings.gpg.enableSshAgent or true;
      in
      {
        services.gpg-agent.pinentry.package = pkgs.pinentry_mac;

        # Darwin equivalent of the socket above: home-manager hangs it off the
        # launchd agent, again gated on the option we are not setting.
        launchd.agents.gpg-agent.config = lib.mkIf enableSshAgent {
          RunAtLoad = true;
          Sockets.Ssh = {
            SockType = "stream";
            SockPathName = "${config.programs.gpg.homedir}/S.gpg-agent.ssh";
            SockPathMode = 384; # 0600; plists have no octal literals.
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
