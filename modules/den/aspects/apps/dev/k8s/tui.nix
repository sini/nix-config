_: {
  den.aspects.apps.dev.k8s.tui = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.click
          pkgs.kubectl-explore
          pkgs.ktop
          pkgs.lens
          pkgs.kube-prompt
        ];
      };
  };
}
