{

  users.deterministicIds =
    let
      uidGid = id: {
        uid = id;
        gid = id;
      };
    in
    {
      sini = uidGid 1000;
      podman = {
        uid = 1027;
        gid = 65536;
      };
      systemd-oom = uidGid 999;
      systemd-coredump = uidGid 998;
      sshd = uidGid 997;
      nscd = uidGid 996;
      polkituser = uidGid 995;
      microvm = uidGid 994;
    };

}
