_: {
  den.aspects.apps.gpg = {
    nixos = {
      services.pcscd.enable = true;
      hardware.gpgSmartcards.enable = true;
    };

    homeManager =
      { pkgs, lib, ... }:
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
            enableSshSupport = true;

            enableBashIntegration = true;
            enableZshIntegration = true;
            enableFishIntegration = true;
            enableNushellIntegration = true;

            defaultCacheTtl = 43200;
            defaultCacheTtlSsh = 43200;
            maxCacheTtl = 86400;
            maxCacheTtlSsh = 86400;

            pinentry.package = lib.mkDefault pkgs.pinentry-tty;

            extraConfig = ''
              ttyname $GPG_TTY
            '';
          };
        };
      };

    homeDarwin =
      { pkgs, ... }:
      {
        services.gpg-agent.pinentry.package = pkgs.pinentry_mac;
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
