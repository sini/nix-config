# Kube-tools role: comprehensive Kubernetes tooling bundle.
{ den, ... }:
{
  den.aspects.kube-tools = {
    includes = [
      den.aspects.kube-core
      den.aspects.kube-helm
      den.aspects.kube-security
      den.aspects.kube-tui
      den.aspects.kube-dev
      den.aspects.kube-plugins
      den.aspects.kube-observability
      den.aspects.kube-utils
    ];
  };
}
