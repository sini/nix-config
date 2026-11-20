# The Syncthing hub's devices and folders, shared by the host hub (hub.nix) and
# the cluster's (kubernetes/services/network/syncthing-hub.nix), so both render
# the same mesh. In services.syncthing.settings shape:
#   devices.<hostname> = { id; addresses; }
#   folders.<id>       = { id; label; path; devices = [ hostname ]; versioning; }
# Folder ids are stfolder-<sha256 "user:dir">, as the members compute them
# (member.nix), so the hub's folders match theirs.
{ lib }:
{
  settings =
    {
      # Every syncthing-peers record the hub receives; its own is dropped.
      syncthing-peers,
      # The members' replicateHome broadcasts, one per (user, host).
      replicateHome,
      # The hub's own hostname in syncthing-peers.
      self,
      # Where the hub keeps each user's folders: <dataDir>/<user>/<dir>.
      dataDir,
    }:
    let
      members = lib.filter (
        q: q.hostname != self && (q.deviceId or null) != null && (q.user or null) != null
      ) syncthing-peers;
      users = lib.unique (map (r: r.user) replicateHome);
      dirsForUser =
        u: lib.unique (lib.concatMap (r: r.directories or [ ]) (lib.filter (r: r.user == u) replicateHome));
      hostsForUser = u: lib.unique (map (q: q.hostname) (lib.filter (q: q.user == u) members));
      folderId = u: p: "stfolder-" + builtins.hashString "sha256" "${u}:${p}";
      # Append-only session logs (projects, …) only need delete-propagation
      # protection, not `staggered`'s growth snapshots, which on the hub (the
      # aggregate of every member's churn) would balloon `.stversions`. `trashcan`
      # keeps just the last replaced or deleted copy; `memory` (small, curated)
      # keeps its `staggered` edit history.
      versioningFor =
        p:
        if baseNameOf p == "memory" then
          {
            type = "staggered";
            params.maxAge = "2592000"; # 30 days
          }
        else
          {
            type = "trashcan";
            params.cleanoutDays = "30";
          };
    in
    {
      devices = lib.listToAttrs (
        map (
          q:
          lib.nameValuePair q.hostname {
            id = q.deviceId;
            inherit (q) addresses;
          }
        ) members
      );
      folders = lib.listToAttrs (
        lib.concatMap (
          u:
          map (
            p:
            lib.nameValuePair (folderId u p) {
              id = folderId u p;
              label = "${u}/${p}";
              path = "${dataDir}/${u}/${p}";
              devices = hostsForUser u;
              versioning = versioningFor p;
            }
          ) (dirsForUser u)
        ) users
      );
    };
}
