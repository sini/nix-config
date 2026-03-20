{
  perSystem =
    { config, ... }:
    {
      devshells.default.commands = [
        {
          package = config.packages.generate-vault-certs;
          name = "generate-vault-certs";
          help = "Generate certificates for Vault raft cluster";
        }
        {
          package = config.packages.generate-user-keys;
          name = "generate-user-keys";
          help = "Generate and encrypt ed25519 SSH keys for users";
        }
      ];
    };
}
