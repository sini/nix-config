{
  users.will = {
    identity = {
      sshKeys = [
        {
          tag = "best-laptop-ever";
          key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMKKUMmeJtEOYi6rU0tumxlrZjH9Y3FCyOhVFIpu3LF1 will.t.bryant@gmail.com";
        }
      ];
    };

    system = {
      enableUnixAccount = true;
      uid = 1002;
      gid = 1002;
    };
  };
}
