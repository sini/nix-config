# AMD GPU device plugin — ROCm k8s device plugin DaemonSet.
#
# Ported from main:modules/kubernetes/hardware/amd-gpu-device-plugin.nix
_: {
  den.aspects.kubernetes.amd-gpu-device-plugin = {
    k8s-manifests =
      { charts, ... }:
      {
        applications.amd-gpu-device-plugin = {
          namespace = "kube-system";

          helm.releases.rocm-k8s-device-plugin = {
            chart = charts.rocm.amd-gpu;
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
