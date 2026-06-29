# GarageCluster — 3-node, RF=3, auto-layout, k8s peer discovery, ClusterIP.
# The operator (garage-operator.nix) reconciles this single CR into the storage
# StatefulSet, Services, garage.toml, and PodDisruptionBudget.
#
# Field paths follow the storage version of the GarageCluster CRD (v1beta2 — the
# only `storage: true` version after T4 stripped the conversion webhooks). The
# nixidy typed accessor (`resources.garageClusters`, from the T4 crds bridge)
# derives the apiVersion from the registered CRD, so this file writes only the
# spec.
{
  den.aspects.kubernetes.services.storage.garage.garage-cluster = {
    k8s-manifests =
      { cluster, ... }:
      let
        inherit (cluster.settings.kubernetes.services.storage.garage.garage) storageBackend;
        # spec §5.3: Garage RF=3 owns redundancy, so never the 2-replica default
        # class (would be 6 copies under RF3).
        #   longhorn   -> data+meta longhorn-single
        #   hybrid     -> data longhorn-single, meta local-path
        #   local-path -> data+meta local-path
        dataClass = if storageBackend == "local-path" then "local-path" else "longhorn-single";
        metaClass = if storageBackend == "longhorn" then "longhorn-single" else "local-path";
      in
      {
        # Anchor the shared app namespace here (every garage aspect merges into
        # applications.garage — secrets.nix adds resources.secrets; this file adds
        # the cluster CR + Services. Identical-string namespace is conflict-free).
        applications.garage.namespace = "garage";
        applications.garage.resources = {
          garageClusters.garage.spec = {
            zone = "axon";
            storage = {
              replicas = 3;
              data = {
                size = "50Gi";
                storageClassName = dataClass;
              };
              metadata = {
                size = "5Gi";
                storageClassName = metaClass;
              };
            };
            database.engine = "lmdb"; # CRD enum: lmdb (default) | sqlite | fjall.
            replication.factor = 3;
            discovery.kubernetes.enabled = true;
            layoutManagement = {
              autoApply = true;
              minNodesHealthy = 2;
            };
            layoutPolicy = "Auto";
            network = {
              rpcBindPort = 3901;
              service.type = "ClusterIP";
              # rpc-secret / admin-token from secrets.nix (T3): 32-byte hex.
              rpcSecretRef = {
                name = "garage-rpc-secret";
                key = "rpc-secret";
              };
            };
            admin = {
              bindPort = 3903;
              adminTokenSecretRef = {
                name = "garage-admin-token";
                key = "admin-token";
              };
            };
            s3Api = {
              bindPort = 3900;
              region = "garage";
              # Leading dot enables vhost-style (bucket.<rootDomain>) Host matching.
              rootDomain = ".s3.json64.dev";
            };
          };

          # NB: the operator creates and OWNS the cluster Services from the
          # GarageCluster spec above — `garage` (s3 :3900 / admin :3903 / web :3902)
          # and `garage-headless` (rpc :3901). Do NOT hand-declare them here: a
          # duplicate `garage` Service collides with the operator's (two managers
          # fighting the same object) and leaves the ArgoCD app permanently
          # OutOfSync. Consumers reference the operator's `garage` Service by name
          # (routes -> garage:3900, garage-ui -> garage:3903).
        };
      };
  };
}
