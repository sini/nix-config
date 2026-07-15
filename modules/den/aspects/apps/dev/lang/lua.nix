{
  den.aspects.apps.dev.lang.lua = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.luaformatter
          pkgs.luajit
          pkgs.lua-language-server
          pkgs.stylua
        ];
      };

    codium-settings = [
      {
        "[lua]"."editor.defaultFormatter" = "JohnnyMorganz.stylua";
      }
    ];

    codium-extensions =
      { pkgs, ... }:
      [
        pkgs.vscode-marketplace.alexgb.nelua
        pkgs.vscode-marketplace.ismoh-games.second-local-lua-debugger-vscode
        pkgs.vscode-marketplace.johnnymorganz.stylua
        pkgs.vscode-marketplace.pollywoggames.pico8-ls
        pkgs.vscode-marketplace.yinfei.luahelper
      ];
  };
}
