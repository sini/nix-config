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
{
  den.aspects.core.network.syncthing.hub = {
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
          hub = (import ./_hub-settings.nix { inherit lib; }).settings {
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
