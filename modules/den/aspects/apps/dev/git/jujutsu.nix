{
  den.aspects.apps.dev.git.jujutsu = {
    homeManager =
      { user, ... }:
      {
        programs.jujutsu = {
          enable = true;
          settings.signing.sign-all = true;
          backend = "gpg";
          key = user.identity.gpgKey;
        };

      };
  };
}
