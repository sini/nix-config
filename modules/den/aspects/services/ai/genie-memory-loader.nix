# The hindsight write token for the `genie-memory` bank, for reloading that bank.
# A rekey target of the one generator in kubernetes/services/ai/hindsight.nix
# (same rekeyFile, no generator here), so the pod's SopsSecret and this copy hold
# the same token. Only this bank's token. Per-user and 0400. Included for
# sini@cortex.
{ rootPath, ... }:
{
  den.aspects.services.ai.genie-memory-loader = {
    homeManager =
      { config, ... }:
      {
        age.secrets.hindsight-write-token-genie-memory = {
          rekeyFile = rootPath + "/.secrets/env/prod/hindsight/write-token-genie-memory.age";
          mode = "400";
          path = "${config.home.homeDirectory}/.config/hindsight/genie-memory-write-token";
        };
      };
  };
}
