# model-egress-check: only the allow-listed service accounts of
# model-egress.nix reach the cortex-cuda model ports, asserted over the
# committed render (nixidy-sync keeps it current).
#   nix build .#checks.x86_64-linux.model-egress
let
  rendered = ../../../../../../generated/manifests/prod-axon;
in
{
  perSystem =
    { pkgs, ... }:
    {
      checks.model-egress =
        pkgs.runCommand "model-egress"
          { nativeBuildInputs = [ (pkgs.python3.withPackages (p: [ p.pyyaml ])) ]; }
          ''
            python3 -I ${./model-egress-check.py} ${rendered}
            touch $out
          '';
    };
}
