{
  flake.kubernetes.services.amd-gpu-device-plugin = {
    nixidy =
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
