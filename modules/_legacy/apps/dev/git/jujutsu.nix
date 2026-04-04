{
  features.jujutsu.home =
    { lib, user, ... }:
    let
      gpgKey = user.identity.gpgKey or null;
    in
    {
      programs.jujutsu = {
        enable = true;
        settings.signing = {
          sign-all = gpgKey != null;
        }
        // lib.optionalAttrs (gpgKey != null) {
          backend = "gpg";
          key = gpgKey;
        };
      };
    };
}
