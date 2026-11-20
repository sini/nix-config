# The user's GitHub SSH key as a user agenix secret, out of the rbw vault (owner,
# 2026-11-20): unlocking the vault takes the master password, which gates every
# password, so a host that restarts unattended (uplink-dev) lost GitHub with each
# restart. The key alone stays on the hosts that need it; the vault keeps the rest.
#
# Self-gated on the encrypted file: no file, nothing changes. Import it from the
# vault once, without the private key touching a terminal:
#   umask 077; rbw get --raw github-auth | jq -r .data.private_key > /dev/shm/k
#   agenix edit -i /dev/shm/k .secrets/users/<user>/github-ssh-key.age
#   shred -u /dev/shm/k
{ lib, rootPath, ... }:
{
  den.aspects.applications.dev.security.github-ssh-key = {
    homeManager =
      { user, config, ... }:
      let
        file = rootPath + "/.secrets/users/${user.name}/github-ssh-key.age";
        # A static path, not agenix's shell-string default, so ssh_config can name it
        # (signing-key.nix explains why).
        path = "${config.home.homeDirectory}/.ssh/id_github";
      in
      lib.mkIf (builtins.pathExists file) {
        age.secrets.github-ssh-key = {
          rekeyFile = file;
          mode = "600";
          inherit path;
        };
        # Tried after the agent's keys, so a host that still has the vault key in its
        # agent behaves as before.
        programs.ssh.settings = {
          "github.com".identityFile = [ path ];
          github.identityFile = [ path ];
        };
      };
  };
}
