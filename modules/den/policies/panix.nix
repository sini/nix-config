# Per-host capture of `panix` class fragments (classes/panix.nix) into
# flake.panixModules.<host>, read by batteries/panix. Same mechanism as
# colmena's host-modules-capture; wired only with den.panix.enableClass.
{
  den,
  lib,
  config,
  ...
}:
let
  cfg = config.den.panix;
in
{
  den.policies.panix-fragments =
    { host, ... }:
    [
      (den.lib.policy.instantiate {
        name = "${host.name}-panix";
        class = "panix";
        instantiate = { modules, ... }: modules;
        intoAttr = [
          "panixModules"
          host.name
        ];
      })
    ];

  # den reads schema includes as a raw list (no mkIf), hence optionals.
  den.schema.host.includes = lib.optionals (cfg.enable && cfg.enableClass) [
    den.policies.panix-fragments
  ];
}
