{ inputs, ... }:

{
  imports = [
    inputs.treefmt-nix.flakeModule
  ];

  perSystem =
    {
      config,
      pkgs,
      ...
    }:
    {
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
          mdformat.enable = true;
          nixfmt = {
            enable = true;
            package = pkgs.nixfmt-rfc-style;
          };
          nixf-diagnose.enable = true;
          prettier.enable = true;
          shfmt.enable = true;
          taplo.enable = true;
        };
      };
    };
}
