{ den, ... }:
{
  den.aspects.kube-core = den.lib.perUser {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          kubectl
          kubecfg
          kubectx
          kubecolor
          kconf
          konf
          kubecm
          kubeswitch
          kns
        ];
      };
  };
}
