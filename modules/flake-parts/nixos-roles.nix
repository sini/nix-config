{ lib, ... }:
{
  options.flake.role = lib.mkOption {
    type = lib.types.attrsOf lib.types.deferredModule;
    default = { };
    description = "NixOS role modules that can be used in host configurations";
  };
}
