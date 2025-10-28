##################################################
# NOTES:
#
#   For YubiKey first-time setup;
#
#     - Set the PINs for user and admin.
#
#       gpg --card-edit
#       admin
#       passwd
#
#     - Enable touch settings
#
#       ykman openpgp keys set-touch aut on
#       ykman openpgp keys set-touch sig on
#       ykman openpgp keys set-touch enc on
#
#     - Check the status
#
#       gpg --card-status
#
#   For importing from YubiKey;
#
#     - Import the keys
#
#       gpg --card-edit
#       fetch
#
#   Or;
#
#     gpg --import ./secrets/pub/*.asc
#
#
#   To Test GPG;
#
#     echo "This is a test message for YubiKey signing." | gpg --sign --armor --output test.sig
#     gpg --verify test.sig
#
##################################################
# { rootPath, lib, ... }:
# let
#   # Holds a concatenated list of all GPG public keys in the secrets/keys directory.
#   gpg-public-keys =
#     let
#       keysDir = rootPath + ".secrets/pub";
#       findAscFiles =
#         dir:
#         let
#           entries = builtins.readDir dir;
#           files = lib.mapAttrsToList (
#             name: type:
#             let
#               path = dir + "/${name}";
#             in
#             if type == "regular" && lib.hasSuffix ".asc" name then
#               [ path ]
#             else if type == "directory" then
#               findAscFiles path
#             else
#               [ ]
#           ) entries;
#         in
#         lib.flatten files;
#       # Get all .asc files and read their contents
#       ascFiles = findAscFiles keysDir;
#       readFiles = map (path: builtins.readFile path) ascFiles;
#     in
#     lib.concatStringsSep "\n\n" readFiles;
# in
{

  flake.features.gpg = {
    nixos = {
      services.pcscd.enable = true;
      hardware.gpgSmartcards.enable = true;
    };

    home =
      {
        pkgs,
        ...
      }:
      {
        programs.gpg = {
          enable = true;

          # publicKeys = [ { source = "${config.xdg.configFile.pubkeys.source}"; } ];

          # PCSCD
          # Smart Card Daemon settings.
          # https://www.gnupg.org/documentation/manuals/gnupg/Scdaemon-Options.html
          scdaemonSettings = {
            # Disable the Internal CCID driver and rely on PC/SCD instead.
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
            enableExtraSocket = true;
            enableSshSupport = true;

            enableBashIntegration = true;
            enableZshIntegration = true;
            enableFishIntegration = true;
            enableNushellIntegration = true;

            defaultCacheTtl = 43200; # 12h
            defaultCacheTtlSsh = 43200;
            maxCacheTtl = 86400; # 24h
            maxCacheTtlSsh = 86400;

            # TODO: If system is darwin, use pinentry-mac
            pinentry.package = pkgs.pinentry-gnome3;

            extraConfig = ''
              ttyname $GPG_TTY
            '';
          };
        };

        # xdg.configFile = {
        #   "pubkeys" = {
        #     target = "nixpkgs/files/pubkeys.txt";
        #     text = gpg-public-keys;
        #   };
        # };
        home.persistence."/persist".directories = [
          ".gnupg"
        ];
      };
  };
}
