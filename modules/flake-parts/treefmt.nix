{ inputs, ... }:

{
  imports = [
    inputs.treefmt-nix.flakeModule
  ];

  perSystem =
    {
      inputs',
      config,
      pkgs,
      ...
    }:
    {

      devshells.default.packages = [ inputs'.statix.packages.default ];

      # Provide a formatter package for `nix fmt`. Setting this
      # to `config.treefmt.build.wrapper` will use the treefmt
      # package wrapped with my desired configuration.
      formatter = config.treefmt.build.wrapper;

      treefmt = {
        projectRootFile = "flake.nix";
        enableDefaultExcludes = true;

        settings = {
          on-unmatched = "fatal";
          global.excludes = [
            "generated/**"
            ".secrets/**"
            "*.editorconfig"
            "*.envrc"
            "*.gitconfig"
            "*.gitignore"
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
            "*.asc"
            "*.org"
            "*.zsh"
            "*.kdl"
            "*.txt"
            "*.tmpl"
            "*.jwe"
            "*.xml"
            "*.dds"
            "*.diff"
            "*.bin"
            # Underscore-prefixed files/dirs are ignored by the module auto-import system
            "**/_*/**"
            "**/_*"
          ];
          statix.options = [ "explain" ];
          mdformat.options = [ "--number" ];
          deadnix.options = [ "--no-lambda-pattern-names" ];
          shellcheck.options = [
            "--shell=bash"
            "--check-sourced"
          ];
          yamlfmt.options = [
            "-formatter"
            "retain_line_breaks=true"
          ];
          formatter = {
            prettier = {
              options = [
                "--tab-width"
                "2"
              ];
              includes = [ "*.{css,html,js,json,jsx,md,mdx,scss,ts,yml,yaml}" ];
            };
          };
        };

        programs = {
          actionlint.enable = true;
          fish_indent.enable = true;
          isort.enable = true;
          nixfmt = {
            enable = true;
            package = pkgs.nixfmt;
          };
          nixf-diagnose.enable = true;
          prettier.enable = true;
          taplo.enable = true;
          # Python formatting
          black.enable = true;
          yamlfmt = {
            enable = true;
            package = pkgs.yamlfmt;
          };
          mdformat = {
            enable = true;
            package = pkgs.mdformat;
          };
          shellcheck = {
            enable = true;
            package = pkgs.shellcheck;
          };
          statix = {
            enable = true;
            package = inputs'.statix.packages.default;
          };
          deadnix = {
            enable = true;
            package = pkgs.deadnix;
          };

        };
      };
    };
}
