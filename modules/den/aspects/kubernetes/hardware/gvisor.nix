# gVisor RuntimeClass — `runtimeClassName: gvisor` runs a pod under the runsc
# containerd handler. Only nodes with services.k3s.gvisor enabled carry the
# handler; they are labelled node.kubernetes.io/gvisor=true, and the
# RuntimeClass's scheduling.nodeSelector keeps gvisor pods on them.
{
  den.aspects.kubernetes.hardware.gvisor = {
    k8s-manifests =
      { ... }:
      {
        applications.gvisor = {
          namespace = "kube-system";

          resources.runtimeClasses.gvisor = {
            handler = "runsc";
            scheduling.nodeSelector."node.kubernetes.io/gvisor" = "true";
          };
        };
      };
  };
}
