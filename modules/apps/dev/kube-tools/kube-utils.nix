{
  features.kube-utils.home =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        clusterctl
        cmctl
        cri-tools
        kubernetes-controller-tools
        kubernetes-code-generator
        kubernix
        kubeone
        kubelogin
        kubelogin-oidc
        kubetail
        kubevirt
        kustomize-sops
        pgo-client
        pv-migrate
        talosctl
        k2tf
        kubergrunt
        kubemqctl
        krelay
        ktunnel
        kube-router
        fetchit
      ];
    };
}
