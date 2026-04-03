{ inputs, ... }:
{
  flake-file.inputs = {
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      # inputs.nixpkgs.follows = "nixpkgs";
    };
  };

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
        # inherit (config.flake-root) projectRootFile;
        projectRootFile = ".git/config";

        enableDefaultExcludes = true;

        settings = {
          # on-unmatched = "fatal";
          on-unmatched = "warn";

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
          ]
          # Exclude generated files from the files.files flake-parts module
          ++ (map (file: file.path_) config.files.files);

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
            ruff-check.priority = 1;
            ruff-format.priority = 2;
            # mdformat.options = [
            #   "--wrap"
            #   "keep"
            # ];
            prettier = {
              options = [
                "--tab-width"
                "2"
              ];
              # includes = [ "*.{css,html,js,json,jsx,scss,ts,yml,yaml}" ];
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
            includes = [ "**/*.nix" ];
          };
          statix = {
            enable = true;
            package = inputs'.statix.packages.default;
            disabled-lints = [
              # W01 bool_comparison
              # W02 empty_let_in
              # W03 manual_inherit
              # W04 manual_inherit_from
              # W05 legacy_let_syntax
              # W06 collapsible_let_in
              # W07 eta_reduction
              # W08 useless_parens
              # W10 empty_pattern
              "empty_pattern"
              # W11 redundant_pattern_bind
              # W12 unquoted_uri
              # W13 deprecated_is_null
              # W14 empty_inherit
              # W15 faster_groupby
              # W16 faster_zipattrswith
              # W17 deprecated_to_path
              # W18 bool_simplification
              # W19 useless_has_attr
              "useless_has_attr"
              # W20 repeated_keys
              "repeated_keys"
              # W23 empty_list_concat
              "empty_list_concat"
            ];
          };
          deadnix = {
            enable = true;
            package = pkgs.deadnix;
          };
          # nixf-diagnose.enable = true;
          prettier = {
            enable = true;
            settings = {
              arrowParens = "always";
              bracketSameLine = false;
              bracketSpacing = true;
              editorconfig = true;
              embeddedLanguageFormatting = "auto";
              endOfLine = "lf";
              # experimentalTernaries = false;
              htmlWhitespaceSensitivity = "css";
              insertPragma = false;
              jsxSingleQuote = true;
              printWidth = 80;
              proseWrap = "always";
              quoteProps = "consistent";
              requirePragma = false;
              semi = true;
              singleAttributePerLine = true;
              singleQuote = false;
              trailingComma = "all";
              useTabs = false;
              vueIndentScriptAndStyle = false;

              tabWidth = 2;
            };
          };

          # Python formatting
          ruff = {
            check = true;
            format = true;
          };

          taplo.enable = true;

          yamlfmt = {
            enable = true;
          };

          toml-sort.enable = true;

          # mdformat.enable = true;

          shellcheck.enable = true;

        };
      };
    };
}
