{ den, ... }:
{
  den.aspects.shuo = {
    includes = [ den.aspects.roles.default ];
  };

  den.users.registry.shuo = {
    system.uid = 1001;
    groups = [
      "users"
      "admins"
      "workstation-access"
    ];
    identity = {
      displayName = "Shuo Diao";
      email = "shuo.diao.nku@gmail.com";
    };
  };
}
