# The per-user `peer` aspect: advertise this user's Syncthing device to the
# same-user mesh and open its sync port. User-scoped (the emit destructures
# `user`); its firewall port reaches the host through den.policies.syncthing-peer-port. Both gate on the
# committed `.id` sidecar's existence — present iff this user replicates (the
# `member` collector's secret generator wrote it), the same `pathExists` idiom
# `userEnrich`/`tailscale` use — so non-replicating users contribute nothing.
{ den, lib, ... }:
let
  addrs = host: environment: p: [
    "tcp://${host.name}.${environment.name}.${environment.domain}:${toString p}"
    "tcp://${host.name}.ts.${environment.domain}:${toString p}"
  ];
in
{
  den.aspects.core.network.syncthing.peer = {
    # Self-gates as a list: emits are forced eagerly during pipe assembly, so a
    # bare `readFile` of a missing `.id` would throw; `pathExists` is lazy, so an
    # absent sidecar yields `[]` and the `readFile` is never reached.
    syncthing-peers =
      {
        host,
        user,
        environment,
        ...
      }:
      let
        idFile = user.secretPath + "/syncthing-${host.name}.id";
        port = 22000 + user.system.syncthingOffset;
      in
      lib.optionals (builtins.pathExists idFile) [
        {
          hostname = host.name;
          user = user.name;
          deviceId = builtins.readFile idFile;
          addresses = addrs host environment port;
        }
      ];

  };

  # Open this user's sync port on the trusted tailnet interface only (never global),
  # on its host by an explicit delivery (den 0.20 `receiver`). Gated on the same
  # sidecar, so only replicating users open one.
  den.policies.syncthing-peer-port =
    { host, user, ... }:
    lib.optional
      (
        host ? class
        && host.class == "nixos"
        && builtins.pathExists (user.secretPath + "/syncthing-${host.name}.id")
      )
      (
        den.lib.policy.provide {
          class = "nixos";
          receiver = host;
          module =
            { config, ... }:
            {
              networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = [
                (22000 + user.system.syncthingOffset)
              ];
            };
        }
      );

  den.schema.user.includes = [
    den.aspects.core.network.syncthing.peer
    den.policies.syncthing-peer-port
  ];
}
