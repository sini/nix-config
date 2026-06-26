# The per-user `peer` aspect: advertise this user's Syncthing device to the
# same-user mesh and open its sync port. User-scoped (the emit destructures
# `user`); bundles the device emit + the firewall `nixos` branch the way
# `agenixUserAspect` bundles `${host.class}` + `homeManager`. Both gate on the
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

    # Open this user's sync port on the trusted tailnet interface only (never
    # global). A user-scoped `nixos` branch fans per user and merges into the
    # host config; gated on the same sidecar so only replicating users open one.
    nixos =
      {
        host,
        user,
        config,
        lib,
        ...
      }:
      lib.mkIf (builtins.pathExists (user.secretPath + "/syncthing-${host.name}.id")) {
        networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = [
          (22000 + user.system.syncthingOffset)
        ];
      };
  };

  den.schema.user.includes = [ den.aspects.core.network.syncthing.peer ];
}
