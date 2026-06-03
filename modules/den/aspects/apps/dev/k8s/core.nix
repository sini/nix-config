{
  den.aspects.apps.dev.k8s.core = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.kubectl
          pkgs.kubecfg
          pkgs.kubectx
          pkgs.kubecolor
          pkgs.kconf
          pkgs.konf
          pkgs.kubecm
          pkgs.kubeswitch
          pkgs.kns
        ];
      };
  };
}
