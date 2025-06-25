{ lib, ... }:
{
  options.flake.meta = lib.mkOption {
    type = with lib.types; lazyAttrsOf anything;
  };
}
