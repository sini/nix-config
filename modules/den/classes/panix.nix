# Panix class: settings fragments for panix.yml (batteries/panix). Off unless
# den.panix.enableClass; policies/panix.nix captures it per host.
{ lib, config, ... }:
let
  cfg = config.den.panix;
in
{
  # den reads den.classes as a raw value (no mkIf), hence optionalAttrs.
  den.classes = lib.optionalAttrs (cfg.enable && cfg.enableClass) {
    panix.description = "panix.yml settings fragments, collected per host (batteries/panix)";
  };
}
