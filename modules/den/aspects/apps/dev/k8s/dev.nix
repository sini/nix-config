{
  den.aspects.apps.dev.k8s.dev = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.devspace
          pkgs.kind
          pkgs.minikube
          pkgs.kops
          pkgs.kluctl
          pkgs.kompose
          pkgs.skaffold
          pkgs.tilt
          pkgs.kail
          pkgs.krane
          pkgs.kpt
          pkgs.kontemplate
          pkgs.timoni
        ];
      };
  };
}
