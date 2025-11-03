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
          pkgs.local.zfs-diff
          (pkgs.writeScriptBin "zfs-root-diff" ''
            ${lib.getExe pkgs.local.zfs-diff} zroot/local/root ${ignoreFilesPkg}
          '')
          (pkgs.writeScriptBin "zfs-home-diff" ''
            ${lib.getExe pkgs.local.zfs-diff} zroot/local/home ${ignoreFilesPkg}
          '')
        ];
      };
  };
}
