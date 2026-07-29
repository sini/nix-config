{ den, ... }:
{
  den.aspects.roles.kube-tools = {
    includes = with den.aspects.applications.dev.k8s; [
      core
      dev
      helm
      observability
      plugins
      security
      tui
      utils
    ];
  };
}
