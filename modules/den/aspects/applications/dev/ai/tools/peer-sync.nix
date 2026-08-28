# peer-sync: installs the local package of the same name.
#
# The tool moves a host's git refs into a peer's remote-tracking namespace so
# in-flight work is transferable between machines that hold separate quota
# accounts — a handoff there is triggered by exhaustion, lands mid-task, and may
# have no quota left to run a sync, so the refs must already be on the peer.
#
# Everything substantive lives in pkgs/by-name/peer-sync/, which also makes it
# runnable without installing: `nix run github:sini/nix-config#peer-sync`.
{
  den.aspects.applications.dev.ai.tools.peer-sync = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.local.peer-sync ];
      };
  };
}
