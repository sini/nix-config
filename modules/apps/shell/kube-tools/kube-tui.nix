{
  features.kube-tui.home =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        click
        kubectl-explore
        ktop
        lens
        kube-prompt
      ];
    };
}
