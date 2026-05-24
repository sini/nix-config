# Devshell class: routes aspect devshell emissions into perSystem.devshells.default.
#
# Aspects can emit devshell commands/packages via the `devshell` class key.
# The flake-parts scope resolves hosts and clusters so their devshell content
# is collected and routed into the devshell module.
{ den, ... }:
let
  inherit (den.lib.policy) route;
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

  den.schema.flake-parts.includes = [
    den.policies.devshell-to-flake-parts
  ];
}
