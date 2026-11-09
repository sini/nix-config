{
  den.aspects.applications.dev.k8s.security = {
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
          # shortcut: karmor 1.4.9's vendored grpc fails to compile in nixpkgs 20261107
          # (undefined: http2.TrailerPrefix); restore it when nixpkgs' build passes.
          # pkgs.karmor
          pkgs.kubestroyer
          pkgs.starboard
          pkgs.kyverno
          pkgs.terrascan
          pkgs.pinniped
        ];
      };
  };
}
