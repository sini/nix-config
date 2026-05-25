{ lib, ... }:
{
  den.aspects.apps.ssh = {
    homeManager =
      { host-addrs, ... }:
      let
        hostMatchBlocks = lib.listToAttrs (
          map (
            entry:
            lib.nameValuePair entry.hostname {
              hostname = "${entry.hostname}.${entry.domain}";
              forwardAgent = true;
            }
          ) host-addrs
        );
      in
      {
        programs.ssh = {
          enable = true;
          enableDefaultConfig = false;
          settings = {
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
          }
          // hostMatchBlocks;
        };
      };

  };
}
