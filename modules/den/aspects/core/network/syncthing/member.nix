{ rootPath, ... }:
{
  # The whole syncthing `member` collector lives here: the per-user `homeManager`
  # block (identity secret + daemon + persistence) and the host-scope `nixos` block
  # (linger + firewall) further down. One file because `member.homeManager` is a
  # single function-valued option — a second definition elsewhere would conflict.
  #
  # The `member` collector fans per-user via roles.default, so its homeManager
  # block sees `replicateHome` and the broadcast-delivered `syncthing-peers`. When
  # a user actually replicates a home dir it: mints a per-(user,host) Syncthing
  # device identity (the agenix-rekey generator writes the cert `.crt` and
  # device-id `.id` sidecars next to the secret and emits the private key on stdout,
  # which agenix-rekey encrypts), runs a per-user `services.syncthing` daemon wired
  # to that user's peer mesh, and persists the replicated dirs (a no-op on darwin).
  #
  # The generator is defined inline rather than imported from
  # _generators-module.nix: that module is host-shaped (references
  # config.networking.fqdn) and would not bind inside home-manager.
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
      home = config.home.homeDirectory; # user-aware: the real resolved home path
      folderId = p: "stfolder-" + builtins.hashString "sha256" "${user.name}:${p}";
      # Share set: this user's daemons on OTHER hosts + the hub. The record carries
      # no per-path `directories` (over-sharing a folder a peer lacks is a no-op),
      # so the filter is purely on identity. Guard `q.user`/`q.isHub` with `or`: the
      # hub record omits `user`, and `||` does NOT short-circuit a throw in its left
      # operand. `deviceId` is defensively re-checked though both emits self-gate.
      sharePeers = lib.filter (
        q:
        q.hostname != host.name
        && ((q.user or null) == user.name || (q.isHub or false))
        && (q.deviceId or null) != null
      ) syncthing-peers;
    in
    # self-gate: no replicateHome ⇒ no identity, no daemon, no persistence (§1a)
    lib.mkIf (dirs != [ ]) {
      age.generators.syncthing-identity =
        { pkgs, file, ... }:
        let
          syncthing = "${pkgs.syncthing}/bin/syncthing";
        in
        ''
          set -euo pipefail
          tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
          # Suppress generate's chatty stdout (only key.pem may reach the secret);
          # let stderr surface so a failure is visible, and `set -e` aborts before
          # `cat key.pem` so a failed generate never emits a garbage identity.
          ${syncthing} generate --home="$tmp" >/dev/null
          base=${lib.escapeShellArg (lib.removeSuffix ".age" file)}
          cp "$tmp/cert.pem" "$base.crt"
          # newline-free: `device-id` appends a trailing \n; strip it so the
          # committed .id is exactly the device ID (consumers read it raw). set
          # -o pipefail keeps a device-id failure fatal.
          ${syncthing} --home="$tmp" device-id | tr -d '\n' > "$base.id"
          cat "$tmp/key.pem"
        '';

      age.secrets.syncthing-identity = {
        rekeyFile = rootPath + "/.secrets/users/${user.name}/syncthing-${host.name}.age";
        generator.script = "syncthing-identity";
      };

      services.syncthing = {
        enable = true;
        overrideDevices = true;
        overrideFolders = true;
        # GUI/REST API on a per-user unix socket — no TCP surface (§5a); the
        # offset governs only the sync port (§5b), and syncthingtray + the CLI
        # auto-detect this address. Pass a PLAIN path (no `unix://`): the HM
        # module's isUnixGui prepends `unix://` for `serve --gui-address` and
        # reuses the same path for its config-apply curl. The path must be
        # eval-resolved (syncthing writes it verbatim, no $VAR expansion) and
        # space-free (the init curl interpolates it unquoted). `config.xdg.cacheHome`
        # satisfies both and is cross-platform (~/.cache on Linux,
        # /Users/<u>/.cache on darwin) — a socket is ephemeral, so cache is its
        # XDG home; the dir already exists, and syncthing unlinks a stale socket
        # on restart (verified). Avoids `/run/user/<uid>` (absent on darwin) and
        # syncthing's data dir (whose darwin path has a space → breaks init curl).
        guiAddress = "${config.xdg.cacheHome}/syncthing.sock";
        # `cert` is `nullOr str`, so coerce the path to its (store) string. The cert
        # is the PUBLIC committed sidecar, so store-copying it is harmless.
        cert = toString (rootPath + "/.secrets/users/${user.name}/syncthing-${host.name}.crt");
        key = config.age.secrets.syncthing-identity.path; # the HM agenix secret (§4)
        settings = {
          # No global discovery, no relays — the mesh is fully declarative and
          # addresses are emitted per peer (§3). Local announce off keeps 21027
          # unbound, so the only listening port is the sync port (§5a).
          options = {
            globalAnnounceEnabled = false;
            localAnnounceEnabled = false;
            relaysEnabled = false;
          };
          # Keyed by hostname; assumed unique within a share set (the hub is a
          # dedicated always-on host, never also one of this user's per-host peers,
          # so no two records collide on `hostname` and drop a distinct deviceId).
          devices = lib.listToAttrs (
            map (
              q:
              lib.nameValuePair q.hostname {
                id = q.deviceId;
                addresses = q.addresses;
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
                  params.maxAge = "2592000"; # 30d rollback net (§7)
                };
              }
            ) dirs
          );
        };
      };

      # Persist the replicated dirs so a root-wipe boot re-syncs deltas instead of
      # re-hashing the whole set. Set unconditionally like persist-home-collector:
      # on Linux this is the real impermanence option, on darwin core.impermanence
      # provides a no-op `home.persistence` dummy (darwin.nix), so it is a
      # cross-platform-safe optimization, never load-bearing (replicated dirs
      # re-sync regardless, §2).
      home.persistence."/persist".directories = dirs;
    };

  # Host scope, runs ONCE per host (member rides roles.default). It cannot read the
  # home-pool `replicateHome`, so it enumerates the host's users via the
  # host-collected `resolved-users` quirk (the established "enumerate users at host
  # scope" mechanism — ddcutil/adb/wireshark all do this) and gates each on
  # `pathExists` of that user's committed `.id` sidecar — present iff that user
  # replicates (the HM secret's generator wrote it, §4). `resolved-users` carries
  # `syncthingOffset` so the firewall port matches the emit's (§5a).
  den.aspects.core.network.syncthing.member.nixos =
    {
      resolved-users,
      host,
      config,
      lib,
      ...
    }:
    let
      idFile = u: rootPath + "/.secrets/users/${u.name}/syncthing-${host.name}.id";
      replicating = lib.filter (u: builtins.pathExists (idFile u)) resolved-users;
      # Trusted transport = the tailnet (reaches every host, LAN or roaming). LAN-direct
      # is an optional latency optimization needing per-host iface names; tailscale0
      # alone is a complete, correct trusted scope (§5b).
      trustedIfaces = [ config.services.tailscale.interfaceName ];
    in
    {
      # linger: the per-user home-manager daemon must run without an active login
      # (§5). mkForce because user-enrich (core.users) already maps the
      # `user.system.linger` schema field to this option at normal priority — a
      # replicating user must linger regardless of that default.
      users.users = lib.listToAttrs (
        map (u: lib.nameValuePair u.name { linger = lib.mkForce true; }) replicating
      );
      # Open each replicating user's sync port on TRUSTED interfaces only — never
      # global, so roaming wifi never sees Syncthing (§5b).
      networking.firewall.interfaces = lib.genAttrs trustedIfaces (_: {
        allowedTCPPorts = map (u: 22000 + u.syncthingOffset) replicating;
      });
    };
}
