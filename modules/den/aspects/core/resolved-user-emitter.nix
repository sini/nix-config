# Emits one resolved-users entry per user at user scope.
# Collected at host scope so host-level aspects can enumerate all users.
_: {
  den.aspects.core.resolved-user-emitter = {
    resolved-users =
      { user, ... }:
      {
        name = user.name;
        uid = user.system.uid or null;
        groups = user.groups or [ ];
        sshKeys = map (k: k.key) (user.identity.sshKeys or [ ]);
      };
  };
}
