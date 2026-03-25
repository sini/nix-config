{
  features.kube-core.home =
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
}
