{
  projectRootFile = "flake.nix";

  programs = {
    actionlint.enable = true;
    biome = {
      enable = true;
      settings.formatter.formatWithErrors = true;
    };
    clang-format.enable = true;
    cmake-format.enable = true;
    deadnix.enable = true;
    deno = {
      enable = true;
      # Using biome for these
      excludes = [
        "*.ts"
        "*.js"
        "*.json"
        "*.jsonc"
      ];
    };
    fish_indent.enable = true;
    gofmt.enable = true;
    isort.enable = true;
    jsonfmt.enable = true;
    mdformat.enable = true;
    nixfmt.enable = true;
    nufmt.enable = true;
    ruff-check.enable = true;
    ruff-format.enable = true;
    rustfmt.enable = true;
    shfmt = {
      enable = true;
      indent_size = 4;
    };
    statix.enable = true;
    stylua.enable = true;
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
      "*.luacheckrc"
      "*CODEOWNERS"
      "*LICENSE"
      "*flake.lock"
      "*.svg"
      "*.png"
      "*.gif"
      "*.ico"
      "*.jpg"
      "*.webp"
      "*Makefile"
      "*Makefile.in"
      "*makefile"
      "*configure.ac"
      "*.xml"
      "*.zsh"
      "*.rasi"
      "*.kdl"
      "*.conf"
    ];

    formatter.ruff-format.options = [ "--isolated" ];
  };
}
