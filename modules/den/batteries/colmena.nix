# Colmena battery: registers the colmena class and wires host modules into
# flake.colmena via policy.instantiate.
{
  den,
  lib,
  config,
  inputs,
  ...
}:
{
  den.classes.colmena = { };

  den.policies.host-to-colmena =
    { host, ... }:
    [
      (den.lib.policy.instantiate {
        inherit (host) name;
        class = "colmena";
        instantiate = { modules, ... }: modules;
        intoAttr = [
          "colmenaNodes"
          host.name
        ];
      })
    ];

  den.schema.host.includes = [ den.policies.host-to-colmena ];

  flake.colmena = {
    meta.nixpkgs = import inputs.nixpkgs-unstable { system = "x86_64-linux"; };
  }
  // lib.mapAttrs (_: modules: {
    imports = modules;
  }) (config.flake.colmenaNodes or { });
}
