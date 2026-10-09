# dns-egress-check: coredns.nix alone grants DNS reachability, asserted over
# the committed render (nixidy-sync keeps it current).
#   nix build .#checks.x86_64-linux.dns-egress
let
  rendered = ../../../../../../../generated/manifests/prod-axon;
in
{
  perSystem =
    { pkgs, ... }:
    {
      checks.dns-egress =
        pkgs.runCommand "dns-egress"
          { nativeBuildInputs = [ (pkgs.python3.withPackages (p: [ p.pyyaml ])) ]; }
          ''
            python3 -I ${./dns-egress-check.py} ${rendered}
            touch $out
          '';
    };
}
