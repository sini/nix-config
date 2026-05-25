{ den, ... }:
{
  den.aspects.roles.kube-tools = {
    colmena = [ "kube-tools" ];
    includes = [ den.aspects.apps.kube-tools ];
  };
}
