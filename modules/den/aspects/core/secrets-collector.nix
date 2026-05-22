{ den, ... }:
{
  den.aspects.core.secrets-collector = {
    nixos = { secrets, lib, ... }: lib.mkMerge secrets;
  };
}
