{ config, ... }:
let
  user = config.flake.meta.user.username;
in
{
  flake.modules.nixos.deterministic-uids = {
    users.deterministicIds =
      let
        uidGid = id: {
          uid = id;
          gid = id;
        };
      in
      {
        ${user} = {
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
          # Maps to Synology NAS user/group for docker user
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
        };
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
        adbusers = uidGid 983;
        msr = uidGid 982;
        gamemode = uidGid 981;
        greeter = uidGid 980;
        uinput = uidGid 979;
        frr = uidGid 978;
        frrvty = uidGid 977;
      };
  };
}
