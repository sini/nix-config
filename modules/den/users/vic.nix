{ den, ... }:
{
  den.aspects.vic = {
    includes = [ den.aspects.roles.default ];
  };

  den.users.registry.vic = {
    system.uid = 1003;
    groups = [
      "users"
      "server-access"
      "grafana.server-admins"
      "open-webui.admins"
    ];
    identity = {
      displayName = "Victor Borja";
      email = "vic@json64.dev";
      sshKeys = [
        {
          tag = "a";
          key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHnnXIJy33RQdITOCDAv1fxBU41Uft1SJOre5S9YdVGH a@github.com";
        }
        {
          tag = "b";
          key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPSIumgbAMxIWAw4Slb2j09ZTz9AgVqdSykKgoQumyqo b@github.com";
        }
      ];
    };
  };
}
