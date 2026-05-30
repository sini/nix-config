{ den, ... }:
{
  den.aspects.theutz = {
    includes = [ den.aspects.core.default ];
  };

  den.users.registry.theutz = {
    system.uid = 1004;
    groups = [
      "users"
      "server-access"
      "grafana.server-admins"
      "open-webui.admins"
    ];
    identity = {
      displayName = "Michael Utz";
      email = "theutz@json64.dev";
      sshKeys = [
        {
          tag = "a";
          key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIbChuj1162NTbJx49GrPJC7qc/mBrXHcDNQO1wbNyJ5 a@github.com";
        }
        {
          tag = "b";
          key = "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIB32rIG1cQdaO9+Kb0ulPJJJ5kUsLcF+mXXW7MBMyd+TAAAABHNzaDo= b@github.com";
        }
        {
          tag = "c";
          key = "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIJpLVjGXLX/o9eIgSfYi2MS15HWE+cOiTteVMlxw/8KtAAAACnNzaDp0aGV1dHo= c@github.com";
        }
      ];
    };
  };
}
