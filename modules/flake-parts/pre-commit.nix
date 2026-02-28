{ lib, inputs, ... }:
{
  imports = [
    inputs.pre-commit-hooks.flakeModule
    inputs.git-hooks-nix.flakeModule
  ];

  text.gitignore = ''
    /.pre-commit-config.yaml
  '';

  perSystem =
    {
      self',
      config,
      ...
    }:
    {
      devshells.default.devshell.startup.pre-commit.text = config.pre-commit.installationScript;

      pre-commit = {
        check.enable = false;

        settings.hooks = {
          treefmt.enable = true;
          nix-fmt = {
            enable = true;
            entry = lib.getExe self'.formatter;
          };
          k8s-update-manifests = {
            enable = true;
            description = "Run k8s-update-manifests to re-generate argocd config";
            name = "k8s-update-manifests";
            entry = "${config.packages.k8s-update-manifests}/bin/k8s-update-manifests --skip-secrets";
            pass_filenames = false;
            files = "^(flake\\.lock|modules/(environments|flake-parts|lib|kubernetes)/.*\\.nix)$";
          };
        };
      };

    };
}
