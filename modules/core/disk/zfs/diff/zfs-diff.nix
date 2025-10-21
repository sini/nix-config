{
  flake.features.zfs-diff = {
    requires = [ "impermanence" ];
    nixos =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      let
        ignoreFilesPkg = pkgs.writeText "ignore_root_paths" (
          lib.concatStringsSep "\n" config.impermanence.ignorePaths
        );
      in
      {
        environment.systemPackages = [
          (pkgs.writeScriptBin "zfs-root-diff" ''
            sudo zfs diff -F zroot/local/root@empty | awk '$2 != "@" && $2 != "/"' | cut -f3- | \
              grep -v -f <(sudo find /persist/ -type f | sed 's|/persist||') | \
              grep -v -f <(sudo find /volatile/ -type f | sed 's|/volatile||') | \
              grep -v -f <(awk '{print "^" $1}' ${ignoreFilesPkg}) | \
              ${pkgs.skim}/bin/sk;
          '')
          (pkgs.writeScriptBin "zfs-home-diff" ''
            sudo zfs diff -F zroot/local/home@empty | awk '$2 != "@" && $2 != "/"' | cut -f3- | \
              grep -v -f <(sudo find /persist/ -type f | sed 's|/persist||') | \
              grep -v -f <(sudo find /volatile/ -type f | sed 's|/volatile||') | \
              grep -v -f <(awk '{print "^" $1}' ${ignoreFilesPkg}) | \
              ${pkgs.skim}/bin/sk;
          '')

        ];
      };
  };
}
