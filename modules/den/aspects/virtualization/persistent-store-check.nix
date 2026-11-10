# The persistent-store programs' pure pieces on fixed data, each with a negative control
# (a mutant that must fail the same case); docs/microvm-persistent-store.md:
#   nix build .#checks.x86_64-linux.microvm-persistent-store
{ lib, ... }:
let
  psLib = import ./_persistent-store.nix { inherit lib; };
  # The serial-length assertion (§2.10), evaluated here: the real predicate must pass the
  # case, a mutant that accepts every serial must fail it.
  serialCase =
    ok:
    ok "uplink-dev-persist"
    && ok "uplink-dev-cache"
    && ok "12345678901234567890"
    && !(ok "123456789012345678901");
  serialChecked =
    assert serialCase psLib.serialOk;
    assert !(serialCase (_: true));
    "ok   serial length (negative control fails)";
in
{
  perSystem =
    { pkgs, ... }:
    {
      checks.microvm-persistent-store = pkgs.runCommand "microvm-persistent-store" { } ''
        echo ${lib.escapeShellArg serialChecked}
        ${pkgs.python3}/bin/python3 -I ${./_persistent-store-test.py} \
          sweep=${./_store-sweep.py} \
          imp=${./_store-roots-import.py} \
          guest=${./_store-guest.py} \
          zvol=${./_state-zvol.py}
        touch $out
      '';
    };
}
