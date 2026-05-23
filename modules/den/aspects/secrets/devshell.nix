# Secrets devshell commands emitted via class routing.
{ den, ... }:
{
  den.aspects.secrets.devshell = {
    devshell =
      { self', ... }:
      {
        commands = [
          {
            package = self'.packages.generate-vault-certs;
            name = "generate-vault-certs";
            help = "Generate certificates for Vault raft cluster";
          }
          {
            package = self'.packages.generate-user-keys;
            name = "generate-user-keys";
            help = "Generate and encrypt ed25519 SSH keys for users";
          }
        ];
      };
  };
  den.schema.flake-parts.includes = [ den.aspects.secrets.devshell ];
}
