{
  den.aspects.apps.dev.lang.nix = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          nix-unit
          nix-eval-jobs
          nil
          nixfmt
          nixpkgs-review
          npins
        ];

        programs.nix-your-shell.enable = true;

      };

    codium-settings =
      { pkgs, lib, ... }:
      [
        {
          "nix.enableLanguageServer" = true;
          "nix.serverPath" = lib.getExe pkgs.nil;
          "nix.serverSettings" = {
            "nil" = {
              "nix" = {
                "flake" = {
                  "autoArchive" = true;
                  "autoEvalInputs" = true;
                  "nixpkgsInputName" = "nixpkgs";
                };
              };
              "formatting" = {
                "command" = [ (lib.getExe pkgs.nixfmt) ];
              };
            };
          };

          "[nix]" = {
            "editor.defaultFormatter" = "jnoortheen.nix-ide";
            "editor.formatOnSave" = true;
            "editor.formatOnPaste" = true;
            "editor.tabSize" = 2;
          };
        }
      ];

    codium-extensions =
      { pkgs, ... }:
      [
        pkgs.vscode-marketplace.jeff-hykin.better-nix-syntax
        pkgs.vscode-marketplace.jnoortheen.nix-ide
        pkgs.vscode-marketplace.pinage404.nix-extension-pack
      ];
  };
}
