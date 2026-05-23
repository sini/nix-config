{ den, ... }:
{
  den.aspects.roles.kube-tools = {
    includes = [ den.aspects.apps.kube-tools ];
  };
}
