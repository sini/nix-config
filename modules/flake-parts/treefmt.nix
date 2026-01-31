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
            "kubernetes/crds/generated/**"
            "kubernetes/manifests/**"
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
            "*.md" # TODO: re-enable after mdformat is fixed
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
          # mdformat.enable = true; #TODO: re-enable when it supports markdown-it-py >= 4.0.0
          nixfmt = {
            enable = true;
            package = pkgs.nixfmt;
          };
          nixf-diagnose.enable = true;
          prettier.enable = true;
          shfmt.enable = true;
          taplo.enable = true;
        };
      };
    };
}
