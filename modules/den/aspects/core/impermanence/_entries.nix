# Every configured persistence entry on a NixOS host, as { live; store; kind; }: the same
# flattening impermanence does (nixos.nix allPersistentStoragePaths), over system roots, their
# `users`, and every Home Manager user's home.persistence. Shared by persist-migrate and
# persist-orphans.
{ lib, config }:
let
  roots = lib.filter (v: v.enable) (lib.attrValues config.environment.persistence);
  hmRoots = lib.filter (v: v.enable) (
    lib.concatMap (u: lib.attrValues (u.home.persistence or { })) (
      lib.attrValues (config.home-manager.users or { })
    )
  );
  all = roots ++ lib.concatMap (r: lib.attrValues (r.users or { })) roots ++ hmRoots;
in
lib.unique (
  map (d: {
    live = d.dirPath;
    store = d.persistentStoragePath;
    kind = "directory";
  }) (lib.concatMap (r: r.directories or [ ]) all)
  ++ map (f: {
    live = f.filePath;
    store = f.persistentStoragePath;
    kind = "file";
  }) (lib.concatMap (r: r.files or [ ]) all)
)
