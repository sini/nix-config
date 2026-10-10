# The HyperQwen API key for a user's agents, at a static path they read at runtime
# (pi `!cat`, opencode `{file:}`). Same rekeyFile and generator as
# services.ai.hyperqwen, so agenix-rekey gives every consumer the same key.
{ rootPath, ... }:
{
  den.aspects.services.ai.hyperqwen-client = {
    homeManager =
      { config, ... }:
      {
        age.secrets.hyperqwen-api-key = {
          rekeyFile = rootPath + "/.secrets/env/dev/hyperqwen/api-key.age";
          generator.script = "hex";
          mode = "400";
          path = "${config.home.homeDirectory}/.config/hyperqwen/api-key";
        };
      };
  };
}
