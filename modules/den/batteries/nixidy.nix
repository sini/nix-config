# Nixidy battery: registers the kubernetes class and collects cluster modules
# via policy.instantiate for nixidy consumption.
{
  den,
  ...
}:
{
  den.classes.k8s-manifests.description = "Kubernetes manifests collected for nixidy";

  den.policies.cluster-to-nixidy =
    { cluster, ... }:
    [
      (den.lib.policy.instantiate {
        inherit (cluster) name;
        class = "k8s-manifests";
        instantiate = { modules, ... }: modules;
        intoAttr = [
          "nixidyModules"
          cluster.name
        ];
      })
    ];

  den.schema.cluster.includes = [ den.policies.cluster-to-nixidy ];
}
