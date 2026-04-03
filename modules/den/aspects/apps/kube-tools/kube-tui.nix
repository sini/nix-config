{ den, ... }:
{
  den.aspects.kube-tui = den.lib.perUser {
    homeManager =
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
  };
}
