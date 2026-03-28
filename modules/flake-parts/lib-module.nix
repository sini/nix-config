{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.flake.lib = mkOption {
    description = "Internal helpers library.";
    type = types.attrsOf (types.attrsOf types.raw);
    default = { };
  };
}
