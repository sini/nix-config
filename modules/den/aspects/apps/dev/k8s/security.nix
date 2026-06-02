_: {
  den.aspects.apps.dev.k8s.security = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.kdigger
          pkgs.kube-bench
          pkgs.kube-score
          pkgs.kubeaudit
          pkgs.kubeclarity
          pkgs.kubesec
          pkgs.kubescape
          pkgs.kubeseal
          pkgs.kubernetes-polaris
          pkgs.karmor
          pkgs.kubestroyer
          pkgs.starboard
          pkgs.kyverno
          pkgs.terrascan
          pkgs.pinniped
        ];
      };
  };
}
