{ lib, ... }:
{
  den.aspects.apps.dev.security.ssh = {
    homeManager =
      { host-addrs, host, ... }:
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
            };
            github = {
              hostname = "github.com";
              user = "git";
            };
          }
          // hostMatchBlocks;
        };
      };

    # macOS only exports SSH_AUTH_SOCK from interactive shell init, so ssh finds
    # no agent in a clean/non-terminal state. gpg-agent runs at login (launchd
    # RunAtLoad) with the YubiKey on its ssh socket, so point ssh straight at it —
    # `ssh <host>` then uses the YubiKey from any context. (NixOS exports
    # SSH_AUTH_SOCK globally via systemd, and IdentityAgent there would shadow a
    # forwarded agent, so this is darwin-only.)
    homeDarwin.programs.ssh.settings."*".identityAgent = "~/.gnupg/S.gpg-agent.ssh";
  };
}
