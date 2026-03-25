{
  features.kube-plugins.home =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        krew
        kubectl-klock
        kubectl-tree
        kubectl-node-shell
        kubectl-images
        kubectl-view-allocations
        kubectl-view-secret
        kubectl-evict-pod
        kubectl-example
        kubectl-convert
        kubectl-doctor
        rakkess
        kfilt
      ];
    };
}
