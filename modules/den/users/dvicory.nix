{ den, ... }:
{
  den.aspects.dvicory = {
    includes = [ den.aspects.roles.default ];
  };

  den.users.registry.dvicory = {
    system.uid = 1006;
    groups = [
      "users"
      "server-access"
      "grafana.server-admins"
      "open-webui.admins"
      "media.admins"
    ];
    identity = {
      displayName = "dvicory";
      email = "dvicory@json64.dev";
      sshKeys = [
        {
          tag = "mbp-2021-32gb";
          key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIABlT9eZfTQyCzzk9ddEfzaVqTJ1JBaMuwL2eZamj14i dvicory@mbp-2021-32gb";
        }
      ];
    };
  };
}
