{ lib, namespace, ... }:
let
  inherit (builtins)
    filter
    map
    ;
  inherit (lib.strings) hasSuffix;
  inherit (lib.lists) flatten;
  inherit (lib.${namespace}) listDirectories;

  listHostsWithArch = flatten (
    map (
      arch:
      map (hostname: {
        "arch" = arch;
        "hostname" = hostname;
      }) (listDirectories "systems/${arch}")
    ) (listDirectories "systems")
  );

  isHostDarwin = { arch, ... }: hasSuffix "darwin" arch;

  darwinHosts = filter isHostDarwin listHostsWithArch;
  linuxHosts = filter (host: !isHostDarwin host) listHostsWithArch;

in
rec {
  inherit
    listHostsWithArch
    isHostDarwin
    darwinHosts
    linuxHosts
    ;
}
