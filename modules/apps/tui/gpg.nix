{
  # TODO: Move to a yubikey module
  flake.modules.nixos.gpg = {
    services.pcscd.enable = true;
    hardware.gpgSmartcards.enable = true;
  };

  flake.modules.homeManager.gpg =
    {
      pkgs,
      ...
    }:

    {
      programs.gpg = {
        enable = true;

        # https://support.yubico.com/hc/en-us/articles/4819584884124-Resolving-GPG-s-CCID-conflicts
        scdaemonSettings = {
          disable-ccid = true;
        };

        # https://github.com/drduh/config/blob/master/gpg.conf
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
          enableSshSupport = true;

          enableBashIntegration = true;
          enableZshIntegration = true;
          enableFishIntegration = true;
          enableNushellIntegration = true;

          # TODO: If system is darwin, use pinentry-mac
          pinentry.package = pkgs.pinentry-gnome3;

          extraConfig = ''
            ttyname $GPG_TTY
          '';
        };
      };
    };
}
