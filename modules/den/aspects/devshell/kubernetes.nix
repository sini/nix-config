# Kubernetes management devshell commands emitted via class routing.
{ den, ... }:
{
  den.aspects.devshell.kubernetes = {
    devshell =
      { self', ... }:
      {
        commands = [
          {
            package = self'.packages.k8s-update-manifests;
            name = "k8s-update-manifests";
            help = "Update Kubernetes manifests for nixidy environments";
          }
          {
            package = self'.packages.toggle-axon-kubernetes;
            name = "toggle-axon-kubernetes";
            help = "Toggle enable/disable Kubernetes on axon cluster nodes";
          }
          {
            package = self'.packages.convert-oidc-secrets;
            name = "convert-oidc-secrets";
            help = "Convert age-encrypted OIDC secrets to SOPS-encrypted YAML format";
          }
        ];
      };
  };
  den.schema.flake-parts.includes = [ den.aspects.devshell.kubernetes ];
}
