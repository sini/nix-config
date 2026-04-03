{ den, ... }:
{
  den.aspects.kube-security = den.lib.perUser {
    homeManager =
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
  };
}
