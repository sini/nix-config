# Group registry placeholder.
#
# Groups are data-only (no isEntity) — they don't get resolved into the
# scope tree. Group data is consumed directly by user access policies
# and will be fully wired in scope-engine (Task 7).
#
# This module declares the den.groups option for future use.
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.den.groups = mkOption {
    type = types.attrsOf (types.attrsOf types.anything);
    default = { };
    description = "Group definitions for access policy resolution";
  };
}
