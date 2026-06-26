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
      # Delivered peers are already same-user (the broadcast scopes by user); just
      # drop self and any peer missing a device id.
      sharePeers = lib.filter (q: q.hostname != host.name && (q.deviceId or null) != null) syncthing-peers;
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
        cert = toString (user.secretPath + "/syncthing-${host.name}.crt"); # HM cert is nullOr str
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
                path = "${home}/${p}";
                devices = map (q: q.hostname) sharePeers;
                versioning = {
                  type = "staggered";
                  params.maxAge = "2592000"; # 30 days
                };
              }
            ) dirs
          );
        };
      };
    };
}
