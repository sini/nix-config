# Garage buckets + keys for the terranix foundation (opentofu state backend +
# Burrito datastore). Co-located in the garage namespace; the operator mints the
# access keys into k8s Secrets, reflector (security/reflector) replicates them to
# the burrito consumer namespace. Future services copy this pattern. Operator-
# minted keys are NOT agenix — the only delivery is reflector.
#
# Field paths follow the storage versions of the CRDs (both v1beta1 — the only
# `storage: true` versions after T4 stripped the conversion webhooks). GarageKey
# v1alpha1 is served=false and GarageBucket v1alpha1 is storage=false, so v1beta1
# is authoritative for both. The nixidy typed accessors (`resources.garageBuckets`
# / `resources.garageKeys`, from the T4 crds bridge) derive the apiVersion from
# the registered CRD, so these write only the spec.
{
  den.aspects.kubernetes.services.storage.garage.buckets = {
    k8s-manifests =
      { ... }:
      let
        # emberstack reflector: allow + auto-replicate the minted Secret into the
        # named consumer namespace.
        reflectTo = ns: {
          "reflector.v1.k8s.emberstack.com/reflection-allowed" = "true";
          "reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces" = ns;
          "reflector.v1.k8s.emberstack.com/reflection-auto-enabled" = "true";
          "reflector.v1.k8s.emberstack.com/reflection-auto-namespaces" = ns;
        };
      in
      {
        applications.garage.resources = {
          # --- opentofu state backend ---
          garageBuckets.opentofu-state.spec.clusterRef.name = "garage";
          garageKeys.opentofu-state.spec = {
            clusterRef.name = "garage";
            bucketPermissions = [
              {
                bucketRef.name = "opentofu-state";
                read = true;
                write = true;
                owner = true;
              }
            ];
            secretTemplate = {
              name = "opentofu-state-s3";
              accessKeyIdKey = "AWS_ACCESS_KEY_ID";
              secretAccessKeyKey = "AWS_SECRET_ACCESS_KEY";
              annotations = reflectTo "burrito";
            };
          };

          # --- Burrito datastore (SP2.3 wires the consumer) ---
          garageBuckets.burrito.spec.clusterRef.name = "garage";
          garageKeys.burrito.spec = {
            clusterRef.name = "garage";
            bucketPermissions = [
              {
                bucketRef.name = "burrito";
                read = true;
                write = true;
                owner = true;
              }
            ];
            secretTemplate = {
              name = "burrito-s3";
              accessKeyIdKey = "AWS_ACCESS_KEY_ID";
              secretAccessKeyKey = "AWS_SECRET_ACCESS_KEY";
              annotations = reflectTo "burrito";
            };
          };
        };
      };
  };
}
