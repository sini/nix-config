{ config, ... }:
let
  inherit (config.node) mainUser;
in
{
  users.deterministicIds =
    let
      uidGid = id: {
        uid = id;
        gid = id;
      };
    in
    {
      ${mainUser} = uidGid 1000;
      media = {
        uid = 1027;
        gid = 65536;
      }; # Maps to Synology NAS user/group for docker user
      systemd-oom = uidGid 999;
      systemd-coredump = uidGid 998;
      sshd = uidGid 997;
      nscd = uidGid 996;
      polkituser = uidGid 995;
      microvm = uidGid 994;
      podman = uidGid 993;
    };
}
