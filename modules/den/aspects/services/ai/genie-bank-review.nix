# The hindsight write token for the `genie` bank, for the owner's
# `genie-bank-review approve` (`--write-token-file`). A rekey target of the one
# generator in kubernetes/services/ai/hindsight.nix (same rekeyFile, no generator
# here), so the pod's SopsSecret and this copy hold the same token. Only this
# bank's token. Per-user and 0400, so the genie tier users cannot read it.
# Included for sini@bitstream.
#
# When the genie root moves to Kubernetes (I12), this becomes a sops target in
# namespace genie and the bitstream target is dropped.
{ rootPath, ... }:
{
  den.aspects.services.ai.genie-bank-review = {
    homeManager =
      { config, ... }:
      {
        age.secrets.hindsight-write-token-genie = {
          rekeyFile = rootPath + "/.secrets/env/prod/hindsight/write-token-genie.age";
          mode = "400";
          path = "${config.home.homeDirectory}/.config/genie-bank-review/write-token";
        };
      };
  };
}
