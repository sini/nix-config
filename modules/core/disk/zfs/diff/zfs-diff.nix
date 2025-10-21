{
  flake.features.zfs-diff.nixos =
    { pkgs, ... }:
    {
      systemd.tmpfiles.rules = [
        "f /persist/ignore_root_paths.txt 0644 root root -"
        "f /persist/ignore_home_paths.txt 0644 root root -"
      ];

      environment.systemPackages = [
        (pkgs.writeScriptBin "zfs-root-diff" ''
          sudo zfs diff -F zroot/local/root@empty | awk '$2 != "@" && $2 != "/"' | cut -f3- | \
            grep -v -f <(sudo find /persist/ -type f | sed 's|/persist||') | \
            grep -v -f <(sudo find /volatile/ -type f | sed 's|/volatile||') | \
            grep -v -f <(awk '{print "^" $1}' /persist/ignore_root_paths.txt) | \
            ${pkgs.skim}/bin/sk;
        '')
        (pkgs.writeScriptBin "zfs-home-diff" ''
          sudo zfs diff -F zroot/local/home@empty | awk '$2 != "@" && $2 != "/"' | cut -f3- | \
            grep -v -f <(sudo find /persist/ -type f | sed 's|/persist||') | \
            grep -v -f <(sudo find /volatile/ -type f | sed 's|/volatile||') | \
            grep -v -f <(awk '{print "^" $1}' /persist/ignore_home_paths.txt) | \
            ${pkgs.skim}/bin/sk;
        '')

      ];
    };
}
