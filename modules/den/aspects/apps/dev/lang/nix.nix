{
  den.aspects.apps.dev.lang.nix = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          nix-unit
          nix-eval-jobs
          nixfmt
          nixpkgs-review
          npins
        ];

        programs.nix-your-shell.enable = true;

      };
  };
}
