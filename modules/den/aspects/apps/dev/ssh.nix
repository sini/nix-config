_: {
  den.aspects.apps.ssh = {
    homeManager = {
      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        matchBlocks = {
          "*" = {
            forwardAgent = false;
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
        };
      };
    };

    persistHome = {
      directories = [
        {
          directory = ".ssh";
          mode = "0700";
        }
      ];
    };
  };
}
