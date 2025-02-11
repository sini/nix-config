{ lib, namespace, ... }:
let
  inherit (builtins)
    filter
    map
    ;
  inherit (lib.strings) hasSuffix;
  inherit (lib.lists) flatten;
  inherit (lib.${namespace}) relativeToRoot listDirectories;

  listHostsWithSystem = flatten (
    map (
      system:
      map (hostname: {
        "system" = system;
        "hostname" = hostname;
        "path" = relativeToRoot "systems/${system}/${hostname}";
      }) (listDirectories "systems/${system}")
    ) (listDirectories "systems")
  );

  isHostDarwin = { system, ... }: hasSuffix "darwin" system;

  darwinHosts = filter isHostDarwin listHostsWithSystem;

  linuxHosts = filter (host: !isHostDarwin host) listHostsWithSystem;
in
rec {
  inherit
    listHostsWithSystem
    isHostDarwin
    darwinHosts
    linuxHosts
    ;
}
