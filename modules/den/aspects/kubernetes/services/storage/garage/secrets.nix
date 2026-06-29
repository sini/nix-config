# Garage rpc_secret + admin_token — agenix-rekey hex generators rekeyed into the
# cluster sops store, consumed by GarageCluster.network.rpcSecretRef /
# admin.adminTokenSecretRef (garage-cluster.nix) and garage-ui (garage-ui.nix).
# Operator-minted S3 access keys do NOT come through here — they are GarageKey
# secretTemplates (buckets.nix).
{
  den.aspects.kubernetes.services.storage.garage.secrets = {
    age-secrets =
      { cluster, config, ... }:
      {
        age.secrets = {
          garage-rpc-secret = {
            rekeyFile = cluster.secretPath + "/garage/rpc-secret.age";
            # 32 bytes -> 64 hex chars: Garage rpc_secret requires exactly 32 bytes.
            generator.script = "hex";
            settings.length = 32;
            sopsOutput = {
              file = "garage";
              key = "rpc-secret";
            };
          };
          garage-admin-token = {
            rekeyFile = cluster.secretPath + "/garage/admin-token.age";
            generator.script = "hex";
            settings.length = 32;
            sopsOutput = {
              file = "garage";
              key = "admin-token";
            };
          };
        };
      };

    k8s-manifests =
      { config, ... }:
      {
        applications.garage.resources.secrets = {
          garage-rpc-secret = {
            type = "Opaque";
            stringData.rpc-secret = config.age.secrets.garage-rpc-secret.sopsRef;
          };
          garage-admin-token = {
            type = "Opaque";
            stringData.admin-token = config.age.secrets.garage-admin-token.sopsRef;
          };
        };
      };
  };
}
