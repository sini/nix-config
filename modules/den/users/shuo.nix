{ den, ... }:
{
  den.aspects.shuo = {
    includes = [ den.aspects.core.default ];
  };

  den.users.registry.shuo = {
    system.uid = 1001;
    groups = [
      "users"
      "workstation-access"
    ];
    identity = {
      email = "shuo@json64.dev";
    };
  };
}
