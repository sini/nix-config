# genie-eval-check: the RBAC, bounds and egress properties of genie-eval.nix,
# asserted over the committed render (nixidy-sync keeps it current).
#   nix build .#checks.x86_64-linux.genie-eval
let
  rendered = ../../../../../../generated/manifests/prod-axon;
in
{
  perSystem =
    { pkgs, ... }:
    {
      checks.genie-eval =
        pkgs.runCommand "genie-eval"
          { nativeBuildInputs = [ (pkgs.python3.withPackages (p: [ p.pyyaml ])) ]; }
          ''
            python3 -I ${./genie-eval-check.py} ${rendered + "/genie-eval"} \
              ${rendered + "/cilium/CiliumClusterwideNetworkPolicy-allow-internal-egress.yaml"} \
              ${rendered + "/coredns/Deployment-coredns.yaml"}
            touch $out
          '';
    };
}
