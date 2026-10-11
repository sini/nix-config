# genie-guard-check: the hardening, identity, egress and shared-socket properties
# of genie-guard.nix, asserted over the aspect's manifests with the flag forced on
# and the pinned images, so the check holds whatever axon's flag is.
#   nix build .#checks.x86_64-linux.genie-guard-pod
{ config, ... }:
let
  manifests = config.den.aspects.kubernetes.services.ai.genie-guard.k8s-manifests {
    config.age.secrets.genie-guard-api-key.sopsRef = "ref+sops://stand-in";
    cluster.settings.kubernetes.services.ai.genie-guard = {
      enable = true;
      hub = "bitstream";
    };
    images = config.flake.imageRefs.x86_64-linux;
  };
in
{
  perSystem =
    { pkgs, ... }:
    {
      checks.genie-guard-pod =
        pkgs.runCommand "genie-guard-pod" { nativeBuildInputs = [ pkgs.python3 ]; }
          ''
            python3 -I ${./genie-guard-check.py} ${pkgs.writeText "genie-guard.json" (builtins.toJSON manifests)}
            touch $out
          '';
    };
}
