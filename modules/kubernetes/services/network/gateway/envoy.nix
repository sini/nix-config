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

    nixidy =
      { lib, ... }:
      {
        applications.envoy-gateway = {
          namespace = "envoy-gateway-system";

          helm.releases.envoy = {
            chart = lib.helm.downloadHelmChart {
              repo = "oci://docker.io/envoyproxy";
              chart = "gateway-helm";
              version = "v1.7.0";
              chartHash = "sha256-JePGNofWs86ZVT1M6FI4Zg79BFvh2KudMnMOHjAbhJM=";
            };
            values = {
              deployment.replicas = 2;
              config.envoyGateway = {
                gateway.controllerName = "gateway.envoyproxy.io/gatewayclass-controller";
                provider = {
                  type = "Kubernetes";
                  kubernetes.deploy.type = "GatewayNamespace";
                };
                extensionApis = {
                  enableEnvoyPatchPolicy = true;
                  enableBackend = true;
                };
                # rateLimit.backend = {
                #   type = "Redis";
                #   redis.url = "envoy-ratelimit-db.envoy-gateway-system.svc.cluster.local:6379";
                # };
              };
            };
          };

          resources = {

            ciliumNetworkPolicies = {

              allow-world-egress.spec = {
                endpointSelector.matchLabels."k8s:io.kubernetes.pod.namespace" = "envoy-gateway-system";
                egress = [
                  {
                    toEntities = [
                      "world"
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "443";
                            protocol = "TCP";
                          }
                          {
                            port = "53";
                            protocol = "UDP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              # Allow all envoy pods to access kube-apiserver
              allow-kube-apiserver-egress.spec = {
                endpointSelector.matchLabels."k8s:io.kubernetes.pod.namespace" = "envoy-gateway-system";
                egress = [
                  {
                    toEntities = [ "kube-apiserver" ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "6443";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              allow-certgen-to-kube-apiserver-egress.spec = {
                endpointSelector.matchLabels."job-name" = "envoy-gateway-helm-certgen";
                egress = [
                  {
                    toEntities = [ "kube-apiserver" ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "6443";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };
            };

          };

        };
      };
  };
}
