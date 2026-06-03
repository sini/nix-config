{
  den.aspects.apps.dev.git.jujutsu = {
    homeManager =
      { user, lib, ... }:
      {
        programs.jujutsu = {
          enable = true;
          # Only configure GPG signing for users who actually have a key.
          # Keyless users (no identity.gpgKey) would otherwise set signing.key
          # to null, which the jujutsu TOML option rejects.
          settings.signing = lib.mkIf (user.identity.gpgKey or null != null) {
            sign-all = true;
            backend = "gpg";
            key = user.identity.gpgKey;
          };
        };
      };
  };
}
