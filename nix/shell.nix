# {
#   perSystem =
#     {
#       inputs',
#       config,
#       pkgs,
#       ...
#     }:
#     {
#       pre-commit.settings.hooks.treefmt.enable = true;
#       devShells.default = pkgs.mkShell {
#         name = "makoto";
#         meta.description = "The default development shell for my NixOS configuration";

#         shellHook = config.pre-commit.installationScript;

#         # Receive packages from treefmt's configured devShell.
#         inputsFrom = [ config.treefmt.build.devShell ];
#         packages = [
#           # Packages provided by flake inputs
#           inputs'.sops-nix.packages.default # agenix CLI for secrets management
#           inputs'.deploy-rs.packages.default # deploy-rs CLI for easy deployments

#           # Packages provided by flake-parts modules
#           config.treefmt.build.wrapper # Quick formatting tree-wide with `treefmt`

#           # Packages from nixpkgs, for Nix, Flakes or local tools.
#           pkgs.git # flakes require Git to be installed, since this repo is version controlled
#         ];
#       };
#     };
# }
{ inputs, ... }:
{
  imports = [
    inputs.devshell.flakeModule
    inputs.pre-commit-hooks.flakeModule
    inputs.treefmt-nix.flakeModule
  ];

  perSystem =
    {
      config,
      pkgs,
      ...
    }:
    {
      pre-commit.settings.hooks.treefmt.enable = true;

      devshells.default = {
        packages = [
          pkgs.nix # Always use the nix version from this flake's nixpkgs version, so that nix-plugins (below) doesn't fail because of different nix versions.
        ];

        commands = [
          {
            package = config.treefmt.build.wrapper;
            help = "Format all files";
          }
          # {
          #   package = pkgs.deploy;
          #   help = "Build and deploy this nix config to nodes";
          # }
          {
            package = pkgs.nix-tree;
            help = "Interactively browse dependency graphs of Nix derivations";
          }
          {
            package = pkgs.nvd;
            help = "Diff two nix toplevels and show which packages were upgraded";
          }
          {
            package = pkgs.nix-diff;
            help = "Explain why two Nix derivations differ";
          }
          {
            package = pkgs.nix-output-monitor;
            help = "Nix Output Monitor (a drop-in alternative for `nix` which shows a build graph)";
          }
          {
            package = pkgs.writeShellApplication {
              name = "build";
              text = ''
                set -euo pipefail
                [[ "$#" -ge 1 ]] \
                  || { echo "usage: build <HOST>..." >&2; exit 1; }
                HOSTS=()
                for h in "$@"; do
                  HOSTS+=(".#nixosConfigurations.$h.config.system.build.toplevel")
                done
                nom build --no-link --print-out-paths --show-trace "''${HOSTS[@]}"
              '';
            };
            help = "Build a host configuration";
          }
        ];

        devshell.startup.pre-commit.text = config.pre-commit.installationScript;
      };

      # Provide a formatter package for `nix fmt`. Setting this
      # to `config.treefmt.build.wrapper` will use the treefmt
      # package wrapped with my desired configuration.
      formatter = config.treefmt.build.wrapper;

      treefmt = {
        projectRootFile = "flake.nix";
        enableDefaultExcludes = true;

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
                "2"
              ];
              includes = [ "*.{css,html,js,json,jsx,md,mdx,scss,ts,yml,yaml}" ];
            };
          };
        };

        programs = {
          actionlint.enable = true;
          deadnix.enable = true;
          fish_indent.enable = true;
          isort.enable = true;
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
        };
      };
    };
}
