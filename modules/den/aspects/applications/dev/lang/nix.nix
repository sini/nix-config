{
  den.aspects.applications.dev.lang.nix = {
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
          "nix.serverPath" = lib.getExe pkgs.nixd;
          "nix.serverSettings" = {
            nil = {
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
            nixd = {
              # nixpkgs.expr = "import (builtins.getFlake (toString ./.)).inputs.nixpkgs { }";
              formatting.command = [ (lib.getExe pkgs.nixfmt) ];
              # options.nixos.expr = "(builtins.getFlake (toString ./.)).nixosConfigurations.cortex.options";
              # options.home-manager.expr = "(builtins.getFlake (builtins.toString ./.)).nixosConfigurations.cortex.options.home-manager.users.type.getSubOptions []";
            };
          };

          "nix.hiddenLanguageServerErrors" = [ "textDocument/definition" ];

          "[nix]" = {
            "editor.defaultFormatter" = "jnoortheen.nix-ide";
            "editor.formatOnSave" = true;
            "editor.formatOnPaste" = true;
            "editor.tabSize" = 2;
            "path-autocomplete.triggerOutsideStrings" = true;
            "path-autocomplete.enableFolderTrailingSlash" = false;
            "editor.fontLigatures" = lib.concatMapStringsSep ", " (s: "'${s}'") [
              "ss01" # == === =/= != !== /= /== ~~ =~ !~
              "ss02" # >= <=
              # "ss03" # -> <- => <!-- --> <~ <~~ <~>
              # "ss04" # </ /> </> /\ \/
              # "ss05" # |> <|
              "ss06" # ## ###
              "ss07" # *** /* */ /*/ (* *) (*)
              # "ss08" # .= .- ..<
              "liga" # <! !! ** :: =: == =! =/ != --
              # "calt" # // /// && ?? ?. ?: || :: ::: ;; .. ... =~= #= := =:= :> >: :> ..= ==-
              # "dlig" # all
            ];
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
