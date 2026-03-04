{
  flake.kubernetes.services.volume-snapshots = {
    crds =
      { pkgs, lib, ... }:
      let
        # nix run nixpkgs#nix-prefetch-github -- kubernetes-csi external-snapshotter --rev v8.5.0
        src = pkgs.fetchFromGitHub {
          owner = "kubernetes-csi";
          repo = "external-snapshotter";
          rev = "v8.5.0";
          hash = "sha256-D+9O6/EBpqaHrQ8mOZoXqjmR/1WfK3BoxuvAYzW7bIE=";
        };
        crds =
          let
            path = "client/config/crd";
          in
          lib.pipe (builtins.readDir "${src}/${path}") [
            (lib.filterAttrs (_name: type: type == "regular"))
            (lib.filterAttrs (name: _type: lib.hasSuffix ".yaml" name))
            builtins.attrNames
            (map (file: "${path}/${file}"))
          ];
      in
      {
        inherit src crds;
      };

    nixidy = {
      applications.volume-snapshots = {
        namespace = "kube-system";
      };
    };
  };
}
