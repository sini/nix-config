{
  inputs,
  ...
}:
{
  imports = [
    inputs.git-hooks-nix.flakeModule
  ];

  text.gitignore = ''
    /.pre-commit-config.yaml
  '';

  perSystem =
    {
      self',
      config,
      inputs',
      pkgs,
      ...
    }:
    {
      devshells.default.devshell.startup.git-hooks.text = config.pre-commit.installationScript;

      pre-commit = {
        check.enable = false;

        # Use prek instead of pre-commit to avoid dotnet dependency
        settings = {
          package = inputs'.git-hooks-nix.packages.prek or pkgs.prek;

          hooks = {
            # Use built-in treefmt hook (runs self'.formatter which is treefmt wrapper)
            treefmt = {
              enable = true;
              package = self'.formatter;
            };

            # Use built-in statix hook with custom package
            statix = {
              enable = true;
              package = inputs'.statix.packages.default;
            };

            # Custom hook: k8s-update-manifests
            k8s-update-manifests = {
              enable = true;
              name = "k8s-update-manifests";
              description = "Run k8s-update-manifests to re-generate argocd config";
              entry = "${config.packages.k8s-update-manifests}/bin/k8s-update-manifests --skip-secrets";
              files = "^(flake\\.lock|modules/(environments|flake-parts|lib|kubernetes)/.*\\.nix)$";
              pass_filenames = false;
            };

            # Custom hook: write-files
            # write-files = {
            #   enable = true;
            #   name = "write-files";
            #   description = "Run write-files to re-generate documentation";
            #   entry = "nix run .#write-files";
            #   files = "\\.nix$";
            #   pass_filenames = false;
            # };
          };
        };
      };
    };
}
