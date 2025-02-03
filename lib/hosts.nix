{ lib, namespace, ... }:
let
  inherit (builtins)
    filter
    map
    ;
  inherit (lib.strings) hasSuffix;
  inherit (lib.lists) flatten;
  inherit (lib.${namespace}) relativeToRoot listDirectories;

  listHostsWithArch = flatten (
    map (
      arch:
      map (hostname: {
        "arch" = arch;
        "hostname" = hostname;
        "path" = relativeToRoot "systems/${arch}/${hostname}";
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
