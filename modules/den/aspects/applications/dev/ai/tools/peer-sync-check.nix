# peer-sync-check: the peer-sync fixture test (pkgs/by-name/peer-sync/test.sh).
#
# Runs the packaged tool against two fixture trees in the sandbox. A fake `ssh`
# first on PATH runs each remote command locally against the "peer" tree, so no
# network or sshd is needed. Covers fast-forward, diverged, dirty peer, absent on
# the peer (created / skipped, and --from with and without --clone-new), a push
# stalled past the per-op timeout, the agent pre-flight hang, --check writing
# nothing, and -j 2 output; each case with a control that must fail.
#   nix build .#checks.x86_64-linux.peer-sync
{ rootPath, ... }:
{
  perSystem =
    { pkgs, config, ... }:
    {
      checks.peer-sync =
        pkgs.runCommand "peer-sync-check"
          {
            nativeBuildInputs = [
              config.packages.peer-sync
              pkgs.git
              pkgs.python3
              pkgs.bash
              pkgs.coreutils
              pkgs.gnugrep
              pkgs.gnused
            ];
          }
          ''
            bash ${rootPath + "/pkgs/by-name/peer-sync/test.sh"} \
              ${config.packages.peer-sync}/bin/peer-sync \
              ${rootPath + "/pkgs/by-name/peer-sync/peer-sync.py"}
            touch $out
          '';
    };
}
