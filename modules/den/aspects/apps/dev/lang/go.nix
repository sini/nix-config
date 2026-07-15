{
  den.aspects.apps.dev.lang.go = {
    homeManager =
      { pkgs, ... }:
      {
        programs.go.enable = true;
        home.packages = with pkgs; [
          gotools
          gopls
        ];
      };

    codium-extensions =
      { pkgs, ... }:
      [
        pkgs.vscode-marketplace.golang.go
      ];
  };
}
