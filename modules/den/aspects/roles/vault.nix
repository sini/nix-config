# Vault role: includes vault service.
{ den, ... }:
{
  den.aspects.vault-role = {
    includes = [
      den.aspects.vault
    ];
  };
}
