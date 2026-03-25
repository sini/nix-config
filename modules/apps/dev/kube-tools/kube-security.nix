{
  features.kube-security.home =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        kdigger
        kube-bench
        kube-score
        kubeaudit
        kubeclarity
        kubesec
        kubescape
        kubeseal
        kubernetes-polaris
        karmor
        kubestroyer
        starboard
        kyverno
        terrascan
        pinniped
      ];
    };
}
