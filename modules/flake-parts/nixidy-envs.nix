{
  self,
  config,
  inputs,
  lib,
  withSystem,
  ...
}:
{
  flake = {
    nixidyEnvs = lib.genAttrs config.systems (
      system:
      (withSystem system (
        { pkgs, ... }:
        inputs.nixidy.lib.mkEnvs {
          inherit pkgs;
          charts = inputs.nixhelm.chartsDerivations.${system};
          envs = {
            prod.modules = [
              ../../k8s/prod/default.nix
            ];
          };
        }
      ))
    );

    generators = lib.genAttrs config.systems (
      system:
      (withSystem system (
        { pkgs, ... }:
        let
          inherit (inputs.nixidy.packages.${system}.generators) fromCRD;
        in
        {
          cert-manager = fromCRD {
            name = "cert-manager";
            src = pkgs.fetchFromGitHub {
              owner = "cert-manager";
              repo = "cert-manager";
              rev = "v1.19.1";
              hash = "sha256-OK6U9QIRYolLBjcNBhzFmZZqfBFoJzY8aUHew2F0MAQ=";
            };
            crds = [
              "deploy/crds/cert-manager.io_certificaterequests.yaml"
              "deploy/crds/cert-manager.io_certificates.yaml"
              "deploy/crds/cert-manager.io_clusterissuers.yaml"
              "deploy/crds/cert-manager.io_issuers.yaml"
              "deploy/crds/acme.cert-manager.io_challenges.yaml"
              "deploy/crds/acme.cert-manager.io_orders.yaml"
            ];
          };

          cilium = fromCRD {
            name = "cilium";
            # nix run nixpkgs#nix-prefetch-github -- cilium cilium --rev v1.18.3
            src = pkgs.fetchFromGitHub {
              owner = "cilium";
              repo = "cilium";
              rev = "v1.18.3";
              hash = "sha256-A73b9aOOYoB0hsdrvVPH1I8/LsZiCZ+NoJc2D3Mdh2g=";
            };
            crds = builtins.map (crd: "pkg/k8s/apis/cilium.io/client/crds/v2/${lib.toLower crd}.yaml") [
              "CiliumBGPPeerConfigs"
              "CiliumBGPClusterConfigs"
              "CiliumBGPAdvertisements"
              "CiliumBGPNodeConfigOverrides"
              "CiliumNetworkPolicies"
              "CiliumLoadBalancerIPPools"
              "CiliumClusterWideNetworkPolicies"
            ];
          };

          traefik = fromCRD {
            name = "traefik";
            src = inputs.nixhelm.chartsDerivations.${system}.traefik.traefik;
            crds = [
              "crds/traefik.io_ingressroutes.yaml"
              "crds/traefik.io_ingressroutetcps.yaml"
              "crds/traefik.io_ingressrouteudps.yaml"
              "crds/traefik.io_middlewares.yaml"
              "crds/traefik.io_middlewaretcps.yaml"
              "crds/traefik.io_serverstransports.yaml"
              "crds/traefik.io_serverstransporttcps.yaml"
              "crds/traefik.io_tlsoptions.yaml"
              "crds/traefik.io_tlsstores.yaml"
              "crds/traefik.io_traefikservices.yaml"
            ];
          };
        }
      ))
    );

  };

  perSystem =
    {
      inputs',
      pkgs,
      system,
      ...
    }:
    {
      devshells.default.packages = [ inputs'.nixidy.packages.default ];
      devshells.default.commands = [
        {
          package = inputs'.nixidy.packages.default;
          help = "Manage kubernetes cluster deployment configuration";
        }
        {
          package = pkgs.writeShellApplication {
            name = "generate-crds";
            text = ''
              set -eo pipefail

              ${lib.concatMapStringsSep "\n" (name: ''
                echo "generate ${name}"
                cat ${self.generators.${system}.${name}} > manifests/crd/${name}.nix
              '') (lib.attrNames self.generators.${system})}
            '';
          };
          help = "Generate CRD definitions";
        }
      ];
    };
}
