{ pkgs, ... }:
{
  projectRootFile = "flake.nix";

  programs = {
    actionlint.enable = true;
    deadnix.enable = true;
    fish_indent.enable = true;
    isort.enable = true;
    jsonfmt.enable = true;
    mdformat.enable = true;
    nixfmt = {
      enable = true;
      package = pkgs.nixfmt-rfc-style;
    };
    nufmt.enable = true;
    prettier.enable = true;
    shfmt = {
      enable = true;
      indent_size = 4;
    };
    statix.enable = true;
    taplo.enable = true;
    yamlfmt.enable = true;
  };

  settings = {
    global.excludes = [
      "*.editorconfig"
      "*.envrc"
      "*.gitconfig"
      "*.git-blame-ignore-revs"
      "*.gitignore"
      "*.gitattributes"
      "*CODEOWNERS"
      "*LICENSE"
      "*flake.lock"
      "*.svg"
      "*.png"
      "*.gif"
      "*.ico"
      "*.jpg"
      "*.webp"
      "*.conf"
      "*.age"
      "*.pub"
      "*.org"
    ];

    formatter = {
      deadnix = {
        priority = 1;
      };

      statix = {
        priority = 2;
      };

      nixfmt = {
        priority = 3;
      };

      prettier = {
        options = [
          "--tab-width"
          "4"
        ];
        includes = [ "*.{css,html,js,json,jsx,md,mdx,scss,ts,yaml}" ];
      };
    };
  };
}
