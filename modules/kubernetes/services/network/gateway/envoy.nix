{
  flake.kubernetes.services.envoy-gateway = {
    crds =
      { pkgs, lib, ... }:
      let
        # nix run nixpkgs#nix-prefetch-github -- envoyproxy gateway --rev v1.7.0
        src = pkgs.fetchFromGitHub {
          owner = "envoyproxy";
          repo = "gateway";
          rev = "v1.7.0";
          hash = "sha256-SlEGwfLeE+utdcqlY//xAvQt89bh2y1GHN/whZZ3XHE=";
        };
        crds =
          let
            path = "charts/gateway-helm/crds/generated";
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
      applications.envoy-gateway = {
        namespace = "kube-system";

        resources = {
          gatewayClasses.envoy.spec.controllerName = "gateway.envoyproxy.io/gatewayclass-controller";
        };

      };
    };
  };
}
