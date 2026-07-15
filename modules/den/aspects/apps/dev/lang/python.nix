{
  den.aspects.apps.dev.lang.python = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.python3
        ];
      };

    codium-settings = [
      {
        "[python]"."editor.formatOnType" = true;
      }
    ];

    codium-extensions =
      { pkgs, ... }:
      [
        pkgs.vscode-marketplace.ms-python.debugpy
        pkgs.vscode-marketplace.ms-python.python
        pkgs.vscode-marketplace.ms-python.vscode-pylance
      ];
  };
}
