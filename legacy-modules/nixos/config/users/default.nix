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
      ${mainUser} = {
        uid = 1000;
        gid = 1000;
        subUidRanges = [
          {
            startUid = 100000;
            count = 65536;
          }
        ];
        subGidRanges = [
          {
            startGid = 100000;
            count = 65536;
          }
        ];
      };
      media = {
        uid = 1027;
        gid = 65536;
        subUidRanges = [
          {
            startUid = 165536;
            count = 65536;
          }
        ];
        subGidRanges = [
          {
            startGid = 165536;
            count = 65536;
          }
        ];
      }; # Maps to Synology NAS user/group for docker user
      systemd-oom = uidGid 999;
      systemd-coredump = uidGid 998;
      sshd = uidGid 997;
      nscd = uidGid 996;
      polkituser = uidGid 995;
      microvm = uidGid 994;
      podman = uidGid 993;
      avahi = uidGid 992;
      colord = uidGid 991;
      geoclue = uidGid 990;
      gnome-remote-desktop = uidGid 989;
      rtkit = uidGid 988;
      nm-iodine = uidGid 987;
      openrazer = uidGid 986;
      resolvconf = uidGid 985;
      fwupd-refresh = uidGid 984;

    };
}
