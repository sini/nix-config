# The always-on Syncthing hub (uplink): ONE system daemon backing up every
# replicating user's dirs under /var/lib/syncthing/<user>/<dir>. No user accounts,
# no per-user daemons. It joins each per-user mesh:
#   - emits its own device record (host scope), broadcast to every member by
#     `broadcast-hub-peer`, so members add it and share their folders with it;
#   - receives each member's device (`broadcast-syncthing-peers-to-hub`) to connect
#     back, and each user's dir set (`broadcast-syncthing-hub-shares`, delivered
#     under `replicateHome`, tagged with the user) to mirror as folders.
# Included + gated `isHub` from uplink.nix (the bgp pattern). Identity is a
# host-level agenix secret (`syncthing-identity` generator) committing the public
# `.crt`/`.id` sidecars, like the per-user member identity.
{ lib, ... }:
{
  den.aspects.core.network.syncthing.hub = {
    # The hub's devices and folders, in services.syncthing.settings shape, read by the
    # host hub (below) and the cluster's (kubernetes/services/network/syncthing-hub.nix)
    # so both render the same mesh. Folder ids are stfolder-<sha256 "user:dir">, as the
    # members compute them (member.nix).
    settings.mesh = lib.mkOption {
      type = lib.types.functionTo lib.types.attrs;
      description = "{ syncthing-peers, replicateHome, self, dataDir } -> { devices; folders; }.";
      default =
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
    };

    # Daemon state + folder data survive the root wipe (uplink wipeRootOnBoot),
    # OWNED by the syncthing service user so it can create the per-user folder
    # roots (/var/lib/syncthing/<user>/...). A plain string entry lands root-owned
    # and syncthing can't mkdir under it ("permission denied" creating folder
    # root); the attrset carries user/group/mode through the persist quirk to
    # impermanence.
    persist.directories = [
      {
        directory = "/var/lib/syncthing";
        user = "syncthing";
        group = "syncthing";
        mode = "0700";
      }
    ];

    # The hub's own device record → broadcast to every member. Self-gated on the
    # committed host identity sidecar (present once minted), like the member emit.
    syncthing-peers =
      {
        host,
        environment,
        lib,
        ...
      }:
      let
        idFile = host.secretPath + "/syncthing-${host.name}.id";
      in
      lib.optionals (builtins.pathExists idFile) [
        {
          hostname = host.name;
          deviceId = builtins.readFile idFile;
          addresses = [
            "tcp://${host.name}.${environment.name}.${environment.domain}:22000"
            "tcp://${host.name}.ts.${environment.domain}:22000"
          ];
          isHub = true;
        }
      ];

    nixos =
      {
        syncthing-peers,
        replicateHome,
        host,
        config,
        lib,
        ...
      }:
      lib.mkIf (host.settings.core.network.syncthing.isHub or false) (
        let
          dataDir = "/var/lib/syncthing";
          hub = host.settings.core.network.syncthing.hub.mesh {
            inherit syncthing-peers replicateHome dataDir;
            self = host.name;
          };
        in
        {
          age.secrets.syncthing-hub-identity = {
            rekeyFile = host.secretPath + "/syncthing-${host.name}.age";
            generator.script = "syncthing-identity";
            owner = "syncthing";
            group = "syncthing";
          };

          services.syncthing = {
            enable = true;
            inherit dataDir;
            overrideDevices = true;
            overrideFolders = true;
            # Import the public cert as its own store path (a real runtime dep that
            # reaches the host, unlike a flake-source path) — same as the member.
            cert = "${builtins.path {
              path = host.secretPath + "/syncthing-${host.name}.crt";
              name = "syncthing-${host.name}.crt";
            }}";
            key = config.age.secrets.syncthing-hub-identity.path;
            settings = {
              # Fully declarative mesh: addressed peers only, no discovery/relays.
              options = {
                globalAnnounceEnabled = false;
                localAnnounceEnabled = false;
                relaysEnabled = false;
              };
              inherit (hub) devices folders;
            };
          };

          # Open the hub's sync port on the trusted tailnet interface only.
          networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = [
            22000
          ];
        }
      );
  };
}
