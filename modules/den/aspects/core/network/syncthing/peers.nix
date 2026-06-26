{ den, lib, rootPath, ... }:
let
  inherit (den.lib.policy) pipe;
  port = user: 22000 + user.system.syncthingOffset;
  addrs = host: environment: p: [
    "tcp://${host.name}.${environment.name}.${environment.domain}:${toString p}"
    "tcp://${host.name}.ts.${environment.domain}:${toString p}"
  ];
  hostIsHub = host: host.settings.core.network.syncthing.isHub or false;
in
{
  # Per-user peer emit. Self-gates as a list: every emit is forced eagerly
  # during pipe assembly, so an unconditional `readFile` of a missing `.id`
  # sidecar would throw fleet-wide. `pathExists` is lazy and never throws, so
  # when the device-id sidecar is absent the emit yields `[]` (no entry) and
  # the `readFile` thunk is never forced.
  den.aspects.core.network.syncthing.peer.syncthing-peers =
    {
      host,
      user,
      environment,
      ...
    }:
    let
      idFile = rootPath + "/.secrets/users/${user.name}/syncthing-${host.name}.id";
      p = port user;
    in
    lib.optionals (builtins.pathExists idFile) [
      {
        hostname = host.name;
        user = user.name;
        deviceId = builtins.readFile idFile;
        port = p;
        isHub = hostIsHub host;
        addresses = addrs host environment p;
      }
    ];

  den.aspects.core.network.syncthing.hub.syncthing-peers =
    { host, environment, ... }:
    let
      idFile = rootPath + "/.secrets/hosts/${host.name}/syncthing-${host.name}.id";
    in
    lib.optionals (builtins.pathExists idFile) [
      {
        hostname = host.name;
        deviceId = builtins.readFile idFile;
        port = 22000;
        isHub = true;
        addresses = addrs host environment 22000;
      }
    ];

  den.policies.broadcast-syncthing-peers-to-users =
    { user, ... }:
    let
      srcUser = user.name;
    in
    [ (pipe.from "syncthing-peers" [ (pipe.broadcast ({ user, ... }: user.name == srcUser)) ]) ];

  den.policies.broadcast-syncthing-peers-to-hub =
    { ... }:
    [
      (pipe.from "syncthing-peers" [
        (pipe.broadcast ({ host, ... }: hostIsHub host))
      ])
    ];

  den.policies.broadcast-hub-peer =
    { host, ... }:
    lib.optionals (hostIsHub host) [
      # `{ user, ... }` is load-bearing, NOT a stray arg: findMatchingAll keys the
      # receiver KIND off `builtins.functionArgs`, so the `user` formal targets
      # every user scope. Do NOT "simplify" to `(_: true)` — no formals matches
      # nothing (spec §3 constraint 1). Body is constant true = all user scopes.
      (pipe.from "syncthing-peers" [ (pipe.broadcast ({ user, ... }: true)) ])
    ];

  den.schema.user.includes = [
    # Base-include the per-user peer aspect (the `syncthing-peers` emit) at USER
    # scope. It must NOT go through a host role (e.g. roles.default): the emit
    # destructures `user`, so a host-scope delivery throws "called without
    # required argument 'user'". This mirrors core.users.resolved-user-emitter /
    # userEnrich, which are user-scoped aspects base-included here. The `member`
    # collector (which fans per-user and reads replicateHome) is included via
    # roles.default instead.
    den.aspects.core.network.syncthing.peer
    den.policies.broadcast-syncthing-peers-to-users
    den.policies.broadcast-syncthing-peers-to-hub
  ];
  den.schema.host.includes = [ den.policies.broadcast-hub-peer ];
}
