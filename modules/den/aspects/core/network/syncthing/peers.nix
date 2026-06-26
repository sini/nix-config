{ den, lib, ... }:
let
  inherit (den.lib.policy) pipe;
  port = user: 22000 + user.system.syncthingOffset;
  addrs = host: environment: p: [
    "tcp://${host.name}.${environment.name}.${environment.domain}:${toString p}"
    "tcp://${host.name}.ts.${environment.domain}:${toString p}"
  ];
in
{
  den.aspects.core.network.syncthing.member.syncthing-peers =
    {
      host,
      user,
      environment,
      ...
    }:
    let
      p = port user;
    in
    {
      hostname = host.name;
      user = user.name;
      port = p;
      isHub = host.settings.core.network.syncthing.isHub or false;
      addresses = addrs host environment p;
    };

  den.aspects.core.network.syncthing.hub.syncthing-peers =
    { host, environment, ... }:
    {
      hostname = host.name;
      port = 22000;
      isHub = true;
      addresses = addrs host environment 22000;
    };

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
        (pipe.broadcast ({ host, ... }: host.settings.core.network.syncthing.isHub or false))
      ])
    ];

  den.policies.broadcast-hub-peer =
    { host, ... }:
    lib.optionals (host.settings.core.network.syncthing.isHub or false) [
      (pipe.from "syncthing-peers" [ (pipe.broadcast ({ user, ... }: true)) ])
    ];

  den.schema.user.includes = [
    # Base-include the per-user member aspect (emit + nixos + homeManager) at
    # USER scope. It must NOT go through a host role (e.g. roles.default): the
    # `syncthing-peers` emit destructures `user`, so a host-scope delivery
    # throws "called without required argument 'user'". This mirrors
    # core.users.resolved-user-emitter / userEnrich, which are user-scoped
    # aspects (the latter even carries a nixos block) base-included here.
    den.aspects.core.network.syncthing.member
    den.policies.broadcast-syncthing-peers-to-users
    den.policies.broadcast-syncthing-peers-to-hub
  ];
  den.schema.host.includes = [ den.policies.broadcast-hub-peer ];
}
