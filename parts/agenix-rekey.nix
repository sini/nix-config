# Based on: https://github.com/oddlama/nix-config/blob/7ccd7856eed93d2ba5b011d6211ff7c4f03a75f0/nix/agenix-rekey.nix
{
  inputs,
  self,
  ...
}:
{
  imports = [
    inputs.agenix-rekey.flakeModule
  ];

  flake = {
    # The identities that are used to rekey agenix secrets and to
    # decrypt all repository-wide secrets.
    secretsConfig = {
      masterIdentities = [ ../secrets/pub/master.pub ];
      #extraEncryptionPubkeys = [ ../secrets/backup.pub ];
    };
  };

  perSystem =
    { config, pkgs, ... }:
    {
      agenix-rekey.nixosConfigurations = self.nodes;
      devshells.default = {
        packages = [
          pkgs.age
          pkgs.age-plugin-yubikey
          config.agenix-rekey.package
        ];
        commands = [
          {
            inherit (config.agenix-rekey) package;
            help = "Edit, generate and rekey secrets";
          }
        ];
        env = [
          {
            # Always add files to git after agenix rekey and agenix generate.
            name = "AGENIX_REKEY_ADD_TO_GIT";
            value = "true";
          }
        ];
      };
    };
}
