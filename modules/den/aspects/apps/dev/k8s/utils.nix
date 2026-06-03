{
  den.aspects.apps.dev.k8s.utils = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.clusterctl
          pkgs.cmctl
          pkgs.cri-tools
          pkgs.kubernetes-controller-tools
          pkgs.kubernetes-code-generator
          pkgs.kubernix
          pkgs.kubeone
          pkgs.kubelogin
          pkgs.kubelogin-oidc
          pkgs.kubetail
          pkgs.kubevirt
          pkgs.kustomize-sops
          pkgs.pgo-client
          pkgs.pv-migrate
          pkgs.talosctl
          pkgs.k2tf
          pkgs.kubergrunt
          pkgs.kubemqctl
          pkgs.krelay
          pkgs.ktunnel
          pkgs.kube-router
          pkgs.fetchit
        ];
      };
  };
}
