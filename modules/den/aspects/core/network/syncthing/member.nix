# The Syncthing `member` collector — included via `roles.default` so its
# `homeManager` fans per user and sees the home-pool `replicateHome`. When a user
# replicates, it mints a per-(user,host) device identity (a home-manager agenix
# secret; the `syncthing-identity` generator lives in `_generators-module.nix`,
# made available to home-manager by `batteries/agenix.nix`'s `sharedModules`) and
# runs that user's `services.syncthing`, wired to the same-user peer mesh.
#
# The replicated dirs stay persisted via the `claude` aspect's `persistHome`, so
# this collector owns no system/firewall content — that is the user-scoped `peer`
# aspect (peers.nix).
{ ... }:
{
  den.aspects.core.network.syncthing.member.homeManager =
    {
      replicateHome,
      syncthing-peers,
      user,
      host,
      lib,
      config,
      ...
    }:
    let
      dirs = lib.unique (lib.concatMap (e: e.directories or [ ]) replicateHome);
      home = config.home.homeDirectory;
      folderId = p: "stfolder-" + builtins.hashString "sha256" "${user.name}:${p}";
      # Session logs (projects, …) are append-only and immutable once written, so
      # `staggered` hoards useless intermediate snapshots of an actively-growing
      # file — at ~60 MB/day of session writes that plateaus near GB-scale on the
      # receivers. `trashcan` keeps only the last replaced/deleted copy (all the
      # delete-propagation protection these logs actually need) for a fraction of
      # the size. `memory` is small + curated, so keep its edit history.
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
      # Delivered peers are already same-user (the broadcast scopes by user); just
      # drop self and any peer missing a device id.
      sharePeers = lib.filter (
        q: q.hostname != host.name && (q.deviceId or null) != null
      ) syncthing-peers;
    in
    lib.mkIf (dirs != [ ]) {
      age.secrets.syncthing-identity = {
        rekeyFile = user.secretPath + "/syncthing-${host.name}.age";
        generator.script = "syncthing-identity";
      };

      services.syncthing = {
        enable = true;
        overrideDevices = true;
        overrideFolders = true;
        # Per-user unix socket in the XDG cache dir: cross-platform, space-free,
        # parent always exists. A leading-`/` path makes the HM module prepend
        # `unix://` for the daemon and reuse the path for its config-apply curl.
        guiAddress = "${config.xdg.cacheHome}/syncthing.sock";
        # Import the (public) cert as its own store path so it's a real runtime
        # dependency copied to remote hosts. A flake-source path (toString of
        # rootPath + …) makes the whole `-source` the dep, which colmena's
        # derivation rewrite drops from the closure it copies — so the cert never
        # reaches remote members. builtins.path materializes just this file.
        cert = "${builtins.path {
          path = user.secretPath + "/syncthing-${host.name}.crt";
          name = "syncthing-${host.name}.crt";
        }}";
        key = config.age.secrets.syncthing-identity.path;
        settings = {
          # Fully declarative mesh: no global/local discovery, no relays — peers
          # are addressed explicitly, so the only listening port is the sync port.
          options = {
            globalAnnounceEnabled = false;
            localAnnounceEnabled = false;
            relaysEnabled = false;
          };
          devices = lib.listToAttrs (
            map (
              q:
              lib.nameValuePair q.hostname {
                id = q.deviceId;
                inherit (q) addresses;
              }
            ) sharePeers
          );
          folders = lib.listToAttrs (
            map (
              p:
              lib.nameValuePair (folderId p) {
                id = folderId p;
                # The relative dir — the `peer` emit broadcasts these labels so
                # the hub can mirror each folder at /var/lib/syncthing/<user>/<p>.
                label = p;
                path = "${home}/${p}";
                devices = map (q: q.hostname) sharePeers;
                versioning = versioningFor p;
              }
            ) dirs
          );
        };
      };
    };
}
