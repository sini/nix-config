{
  den.aspects.apps.dev.k8s.plugins = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.krew
          pkgs.kubectl-klock
          pkgs.kubectl-tree
          pkgs.kubectl-node-shell
          pkgs.kubectl-images
          pkgs.kubectl-view-allocations
          pkgs.kubectl-view-secret
          pkgs.kubectl-evict-pod
          pkgs.kubectl-example
          pkgs.kubectl-convert
          pkgs.kubectl-doctor
          pkgs.rakkess
          pkgs.kfilt
        ];
      };
  };
}
