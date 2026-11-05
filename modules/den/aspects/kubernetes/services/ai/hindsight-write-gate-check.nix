# Hermetic credential-policy regression check. The pinned-upstream HTTP/MCP
# oracle remains separate because it needs hindsight-api-slim and Postgres.
{
  perSystem =
    { pkgs, ... }:
    {
      checks.hindsight-write-gate =
        pkgs.runCommand "hindsight-write-gate" { nativeBuildInputs = [ pkgs.python3 ]; }
          ''
            cp ${./hindsight-write-gate.py} hindsight-write-gate.py
            cp ${./hindsight-write-gate-unit.py} hindsight-write-gate-unit.py
            python3 -I hindsight-write-gate-unit.py
            touch $out
          '';
    };
}
