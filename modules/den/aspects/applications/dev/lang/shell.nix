{
  den.aspects.applications.dev.lang.shell = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.bash-language-server
          pkgs.shellcheck
          pkgs.shfmt
        ];
      };

    codium-settings = [
      {
        "shellcheck.run" = "onSave";
        "shellformat.useEditorConfig" = true;
      }
    ];

    codium-extensions =
      { pkgs, ... }:
      [
        pkgs.vscode-marketplace.bmalehorn.shell-syntax
        pkgs.vscode-marketplace.bmalehorn.vscode-fish
        pkgs.vscode-marketplace.foxundermoon.shell-format
        pkgs.vscode-marketplace.mads-hartmann.bash-ide-vscode
        pkgs.vscode-marketplace.rogalmic.bash-debug
        pkgs.vscode-marketplace.timonwong.shellcheck
      ];
  };
}
