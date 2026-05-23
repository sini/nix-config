# Devshell class: routes aspect devshell emissions into perSystem.devshells.default.
#
# Aspects can emit devshell commands/packages via the `devshell` class key.
# The flake-parts scope resolves hosts and clusters so their devshell content
# is collected and routed into the devshell module.
{ den, ... }:
let
  inherit (den.lib.policy) route resolve;
in
{
  den.classes.devshell = { };

  den.policies.devshell-to-flake-parts = _: [
    (route {
      fromClass = "devshell";
      intoClass = "flake-parts";
      path = [
        "devshells"
        "default"
      ];
      adaptArgs = { config, ... }: config.allModuleArgs;
    })
  ];

  # Enter flake-parts scope from flake-system
  den.schema.flake-system.includes = [ den.policies.system-to-flake-parts ];

  # Resolve hosts and clusters into flake-parts scope so their devshell
  # class content is collected
  den.policies.flake-parts-to-hosts =
    _:
    map (host: resolve.to "host" { inherit host; }) (
      builtins.concatMap builtins.attrValues (builtins.attrValues den.hosts)
    );

  den.policies.flake-parts-to-clusters =
    _:
    map (
      clusterName:
      resolve.to "cluster" {
        cluster = den.clusters.${clusterName} // { name = clusterName; };
      }
    ) (builtins.attrNames (den.clusters or { }));

  den.schema.flake-parts.includes = [
    den.policies.devshell-to-flake-parts
    den.policies.flake-parts-to-hosts
    den.policies.flake-parts-to-clusters
  ];
}
