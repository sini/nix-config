{ lib, ... }:
{
  den.aspects.core.network.syncthing.member.homeManager =
    { syncthing-peers, lib, ... }:
    {
      home.sessionVariables._SYNCTHING_PEERS_DEBUG = lib.concatStringsSep "," (
        lib.sort (a: b: a < b) (
          map (q: "${q.hostname}@${if q.isHub or false then "hub" else q.user or "?"}") syncthing-peers
        )
      );
    };
}
