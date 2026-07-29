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
              # opkssh `login` is file-based: it writes an OIDC-backed SSH cert to
              # ~/.ssh/id_ecdsa(+-cert.pub) and adds nothing to any agent, so the
              # cert never reaches the ssh-agent-mux. Offer that identity directly
              # to the fleet peers whose sshd runs the opkssh AuthorizedKeysCommand
              # verifier. Scoped here (not `*`) so the OIDC identity cert is not
              # advertised to github or other external hosts. The `*` block's
              # signing key is still offered on these hosts (IdentityFile
              # directives accumulate across matching blocks). A missing file
              # (before first `opkssh login`) is skipped by ssh without error.
              identityFile = [ "~/.ssh/id_ecdsa" ];
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
