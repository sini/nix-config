# Gateway API — Gateway resource definitions, GatewayClass for Cilium.
#
# Ported from main:modules/kubernetes/services/network/gateway/gateway-api.nix
{ den, ... }:
{
  den.aspects.kubernetes.gateway-api = {
    k8s-manifests =
      { cluster, ... }:
      {
        applications.gateway-api = {
          namespace = "kube-system";

          resources = {
            gatewayClasses.cilium.spec.controllerName = "io.cilium/gateway-controller";
          };
        };
      };
  };
}
