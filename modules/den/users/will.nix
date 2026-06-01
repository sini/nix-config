{ den, ... }:
{
  den.aspects.will = {
    includes = [ den.aspects.roles.default ];
  };

  den.users.registry.will = {
    system.uid = 1002;
    groups = [
      "users"
      "workstation-access"
    ];
    identity = {
      email = "will@json64.dev";
      sshKeys = [
        {
          tag = "best-laptop-ever";
          key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMKKUMmeJtEOYi6rU0tumxlrZjH9Y3FCyOhVFIpu3LF1 will.t.bryant@gmail.com";
        }
      ];
    };
  };
}
