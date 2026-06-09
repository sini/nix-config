# Kubernetes management devshell commands emitted via class routing.
{ den, ... }:
{
  den.aspects.devshell.kubernetes = {
    devshell =
      { self', ... }:
      {
        commands = [
          {
            package = self'.packages.nixidy-sync;
            name = "nixidy-sync";
            help = "Sync nixidy environment manifests into the repo";
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
