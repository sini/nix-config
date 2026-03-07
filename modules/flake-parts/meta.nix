{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.flake.meta = mkOption {
    type = types.lazyAttrsOf types.anything;
    description = "Flake-level metadata.";
  };

  config.flake.meta.uri = "github:sini/nix-config";
}
