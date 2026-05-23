# Nixidy battery: registers the kubernetes class and collects cluster modules
# via policy.instantiate for nixidy consumption.
{
  den,
  ...
}:
{
  den.classes.kubernetes = { };

  den.policies.cluster-to-nixidy =
    { cluster, ... }:
    [
      (den.lib.policy.instantiate {
        inherit (cluster) name;
        class = "kubernetes";
        instantiate = { modules, ... }: modules;
        intoAttr = [
          "nixidyModules"
          cluster.name
        ];
      })
    ];

  den.schema.cluster.includes = [ den.policies.cluster-to-nixidy ];
}
