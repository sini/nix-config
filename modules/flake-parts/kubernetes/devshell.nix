_:
{
  perSystem =
    { config, ... }:
    {
      devshells.default.commands = [
        {
          package = config.packages.k8s-update-manifests;
          name = "k8s-update-manifests";
          help = "Update Kubernetes manifests for nixidy environments";
        }
        {
          package = config.packages.toggle-axon-kubernetes;
          name = "toggle-axon-kubernetes";
          help = "Toggle enable/disable Kubernetes on axon cluster nodes";
        }
        {
          package = config.packages.convert-oidc-secrets;
          name = "convert-oidc-secrets";
          help = "Convert age-encrypted OIDC secrets to SOPS-encrypted YAML format";
        }
      ];

      pre-commit.settings.hooks.k8s-update-manifests = {
        enable = true;
        name = "k8s-update-manifests";
        description = "Run k8s-update-manifests to re-generate argocd config";
        entry = "${config.packages.k8s-update-manifests}/bin/k8s-update-manifests --skip-secrets";
        files = "^(flake\\.lock|modules/(environments|flake-parts|lib|kubernetes)/.*\\.nix)$";
        pass_filenames = false;
      };
    };
}
