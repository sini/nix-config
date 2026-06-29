# Settings for the garage aspect group. Surfaced onto the cluster as
# `cluster.settings.kubernetes.services.storage.garage.garage.*`; set per
# cluster via
# `den.clusters.<name>.settings.kubernetes.services.storage.garage.garage.<key>`.
{ lib, ... }:
{
  den.aspects.kubernetes.services.storage.garage.garage.settings.storageBackend = lib.mkOption {
    type = lib.types.enum [
      "longhorn"
      "hybrid"
      "local-path"
    ];
    default = "longhorn";
    description = ''
      Garage backing storage. Garage RF=3 owns cross-node redundancy, so the
      volume must NOT double-replicate (the default `longhorn` StorageClass is
      2-replica = 6 copies under RF3 — deliberately avoided).
        longhorn   = data+meta on longhorn-single (1 Longhorn replica; off-cluster
                     NFS backup; survives reset-axon).
        hybrid     = data on longhorn-single (backed up); LMDB meta on node-local
                     local-path (peer-protected, not in the backup set).
        local-path = both node-local; Garage RF=3 the only redundancy; NO volume
                     backup (DR needs a backup cluster).
    '';
  };
}
