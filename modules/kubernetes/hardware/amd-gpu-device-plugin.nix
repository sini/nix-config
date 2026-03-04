{
  flake.kubernetes.services.amd-gpu-device-plugin = {
    # crds =
    #   { pkgs, lib, ... }:
    #   let
    #     # nix run nixpkgs#nix-prefetch-github -- ROCm k8s-device-plugin --rev v1.31.0.9
    #     src = pkgs.fetchFromGitHub {
    #       owner = "ROCm";
    #       repo = "k8s-device-plugin";
    #       rev = "v1.31.0.9";
    #       hash = "sha256-7YOAHkEYCBkZWr2Gyo0SONcAky+ebLEw0eW1CK7KpFk=";
    #     };
    #     crds =
    #       let
    #         path = "config/crd/standard";
    #       in
    #       lib.pipe (builtins.readDir "${src}/${path}") [
    #         (lib.filterAttrs (_name: type: type == "regular"))
    #         (lib.filterAttrs (name: _type: lib.hasSuffix ".yaml" name))
    #         builtins.attrNames
    #         (map (file: "${path}/${file}"))
    #       ];
    #   in
    #   {
    #     inherit src crds;
    #   };

    nixidy =
      { lib, ... }:
      {
        applications.amd-gpu-device-plugin = {
          namespace = "kube-system";

          helm.releases.rocm-k8s-device-plugin = {
            chart = lib.helm.downloadHelmChart {
              repo = "https://rocm.github.io/k8s-device-plugin/";
              chart = "amd-gpu";
              version = "0.21.0"; # App version: 1.31.0.9
              chartHash = "sha256-Rc2Fb0774k7pc8b9eDLhsb6QejVTPY4jYZYRkmks9EI=";
            };
          };

          resources.daemonSets."amd-gpu-device-plugin-daemonset" = {
            spec.template.spec.nodeSelector = {
              "node.kubernetes.io/amd-gpu" = "true";
            };
          };

        };
      };
  };
}
