{ lib, ... }:
{
  den.aspects.applications.dev.security.ssh = {
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
              # The LAN name resolves only through /etc/hosts (core/network/hostsfile),
              # which lists a peer only when it has a declared IPv4. So use the tailnet
              # MagicDNS name on darwin (no hostsfile there, and it roams) and for any
              # peer without a fixed address (a DHCP laptop, a roaming Mac); NixOS keeps
              # the LAN name for the rest (direct over the local network).
              hostname =
                if host.class == "darwin" || entry.ipv4 == [ ] then
                  entry.tsName
                else
                  "${entry.hostname}.${entry.domain}";
              forwardAgent = true;
              # The opkssh OIDC cert is delivered via the ssh-agent-mux, not the
              # ssh config: `opkssh-login` loads ~/.ssh/id_ecdsa into the standard
              # agent (see opkssh-client.nix), so it is presented to these peers
              # over SSH_AUTH_SOCK regardless of how the host is addressed. This
              # is the only path that works for colmena, which targets a bare IP
              # matching no `Host` block. No per-host IdentityFile here.
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
