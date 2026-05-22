{ den, ... }:
{
  den.aspects.core.secrets-collector = {
    nixos = { age-secrets, lib, ... }: lib.mkMerge age-secrets;
  };
}
