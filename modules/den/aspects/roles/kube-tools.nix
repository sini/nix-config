{ den, ... }:
{
  den.aspects.roles.kube-tools = {
    colmena-tags = [ "kube-tools" ];
    includes = [ den.aspects.apps.kube-tools ];
  };
}
