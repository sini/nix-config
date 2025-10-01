{
  flake.aspects.ssh.home = {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks = {
        "*" = {
          forwardAgent = false;
          # "a private key that is used during authentication will be added to ssh-agent if it is running"
          addKeysToAgent = "yes";
          compression = true;
          serverAliveInterval = 0;
          serverAliveCountMax = 3;
          hashKnownHosts = false;
          userKnownHostsFile = "~/.ssh/known_hosts";
          controlMaster = "no";
          controlPath = "~/.ssh/master-%r@%n:%p";
          controlPersist = "no";
        };
        github = {
          hostname = "github.com";
          user = "git";
        };
        "10.10.*" = {
          # "allow to securely use local SSH agent to authenticate on the remote machine."
          # "It has the same effect as adding cli option `ssh -A user@host`"
          forwardAgent = true;
        };
      };
    };
  };
}
