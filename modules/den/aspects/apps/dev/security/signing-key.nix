{ rootPath, ... }:
{
  den.aspects.apps.dev.security.signing-key = {
    homeManager =
      { user, ... }:
      {
        age.secrets.user-signing-key = {
          rekeyFile = rootPath + "/.secrets/users/${user.name}/id_signing.age";
          mode = "600";
          generator.script = "shared-ssh-key";
        };
      };
  };
}
