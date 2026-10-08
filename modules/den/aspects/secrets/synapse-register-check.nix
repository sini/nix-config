# Synapse's register MAC (_synapse-register.py, run by the synapse-bot-token
# generator) on a fixed vector, pinned to a digest computed with openssl:
#   nix build .#checks.x86_64-linux.synapse-register-mac
{
  perSystem =
    { pkgs, ... }:
    {
      checks.synapse-register-mac = pkgs.runCommand "synapse-register-mac" { } ''
        got=$(${pkgs.python3}/bin/python3 -I ${./_synapse-register.py} --self-test)
        [ "$got" = 18e7152ab3f727d2539fb6ded5d4449eab3443a4 ] || { echo "got $got" >&2; exit 1; }
        touch $out
      '';
    };
}
