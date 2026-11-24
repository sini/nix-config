# Emits one resolved-users entry per user at user scope.
# Collected at host scope so host-level aspects can enumerate all users.
{
  den.aspects.core.users.resolved-user-emitter = {
    resolved-users =
      { user, ... }:
      {
        inherit (user) name;
        uid = user.system.uid or null;
        groups = user.facts.groups;
        sshKeys = map (k: k.key) (user.identity.sshKeys or [ ]);
        sshOidcPrincipals = user.identity.sshOidcPrincipals or [ ];
      };
  };
}
