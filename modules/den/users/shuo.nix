{ den, ... }:
{
  den.aspects.shuo = {
    includes = [ den.aspects.roles.default ];
  };

  den.users.shuo = {
    system.uid = 1001;
    facts.groups = [
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
