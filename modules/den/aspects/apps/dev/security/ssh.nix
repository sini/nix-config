{ lib, ... }:
{
  den.aspects.apps.dev.security.ssh = {
    homeManager =
      {
        host-addrs,
        host,
        user,
        secrets,
        ...
      }:
      let
        hostMatchBlocks = lib.listToAttrs (
          map (
            entry:
            lib.nameValuePair entry.hostname {
              # On darwin the LAN /etc/hosts names don't resolve (no hostsfile
              # there, and the host roams), so address peers by their tailnet
              # MagicDNS name, which resolves via the tailscale /etc/resolver
              # route. NixOS keeps the LAN domain (direct over the local network).
              hostname = if host.class == "darwin" then entry.tsName else "${entry.hostname}.${entry.domain}";
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
              # Try agent first, then fall back to the decrypted agenix file.
              identityFile = lib.optional (secrets ? user-signing-key) secrets.user-signing-key;
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
