# The hindsight write token for the `genie` bank, for the owner's
# `genie-bank-review approve` (`--write-token-file`). Only this bank's token:
# genie-memory's stays in the cluster. Same rekeyFile and generator as the
# cluster copy (kubernetes/services/ai/hindsight.nix), so agenix-rekey gives both
# the same token. Per-user and 0400, so the genie tier users cannot read it.
{ rootPath, ... }:
{
  den.aspects.services.ai.genie-bank-review = {
    homeManager =
      { config, ... }:
      {
        age.secrets.hindsight-write-token-genie = {
          rekeyFile = rootPath + "/.secrets/env/prod/hindsight/write-token-genie.age";
          generator.script = "hex";
          mode = "400";
          path = "${config.home.homeDirectory}/.config/genie-bank-review/write-token";
        };
      };
  };
}
