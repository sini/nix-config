{
  flake.kubernetes.services.gateway-api = {
    crds =
      { pkgs, lib, ... }:
      let
        # nix run nixpkgs#nix-prefetch-github -- kubernetes-sigs gateway-api --rev v1.4.1
        src = pkgs.fetchFromGitHub {
          owner = "kubernetes-sigs";
          repo = "gateway-api";
          rev = "v1.4.1";
          hash = "sha256-/GHyikcC2QGDN0ndpY6/xvSEEnpSsLrNU+lFElCKBs8=";
        };
        crds =
          let
            path = "config/crd/standard";
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
      applications.gateway-api = {
        namespace = "kube-system";

        resources = {
          gatewayClasses.cilium.spec.controllerName = "io.cilium/gateway-controller";
        };

      };
    };
  };
}
