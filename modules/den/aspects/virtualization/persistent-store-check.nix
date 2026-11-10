# The persistent-store programs' pure pieces on fixed data, each with a negative control
# (a mutant that must fail the same case); docs/microvm-persistent-store.md:
#   nix build .#checks.x86_64-linux.microvm-persistent-store
{
  perSystem =
    { pkgs, ... }:
    {
      checks.microvm-persistent-store = pkgs.runCommand "microvm-persistent-store" { } ''
        ${pkgs.python3}/bin/python3 -I ${./_persistent-store-test.py} \
          sweep=${./_store-sweep.py} \
          imp=${./_store-roots-import.py} \
          guest=${./_store-guest.py}
        touch $out
      '';
    };
}
