{ config, lib, ... }:
let
  # Generate SSH matchBlocks for each host with agent forwarding
  hostMatchBlocks =
    config.flake.hosts
    |> lib.attrsets.mapAttrs' (
      hostname: hostConfig:
      let
        targetEnv = config.flake.environments.${hostConfig.environment};
        fqdn = "${hostname}.${targetEnv.domain}";
      in
      lib.attrsets.nameValuePair hostname {
        hostname = "${fqdn}";
        forwardAgent = true;
      }
    );

in
{
  flake.features.ssh.home = {
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
      }
      // hostMatchBlocks;
    };
  };
}
