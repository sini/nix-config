# Emberstack reflector — cross-namespace Secret/ConfigMap replication.
#
# Required by the garage stack: GarageKey-minted S3 credential Secrets carry
# reflector annotations (storage/garage/buckets.nix) that replicate them into
# consumer namespaces (e.g. burrito). Deploy ahead of any GarageKey.
{
  den.aspects.kubernetes.services.security.reflector = {
    k8s-manifests =
      { charts, ... }:
      {
        applications.reflector = {
          namespace = "reflector";

          helm.releases.reflector = {
            chart = charts.emberstack.reflector;
          };
        };
      };
  };
}
