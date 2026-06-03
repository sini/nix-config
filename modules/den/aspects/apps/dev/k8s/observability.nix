{
  den.aspects.apps.dev.k8s.observability = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.cilium-cli
          pkgs.hubble
          pkgs.stern
          pkgs.kubeshark
          pkgs.kubespy
          pkgs.kube-capacity
          pkgs.kube-linter
          pkgs.kubeconform
          pkgs.kubeval
          pkgs.datree
          pkgs.popeye
          pkgs.netassert
          pkgs.k8sgpt
        ];
      };
  };
}
