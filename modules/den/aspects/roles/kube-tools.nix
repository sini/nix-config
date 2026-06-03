{ den, ... }:
{
  den.aspects.roles.kube-tools = {
    includes = with den.aspects.apps.dev.k8s; [
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
