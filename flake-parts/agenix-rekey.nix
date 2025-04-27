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
      masterIdentities = [
        {
          identity = ../secrets/pub/master.pub;
          pubkey = "age1yubikey1qwq4shht6jmgpdma3t0nkueqz2w2vfmtgq4jnj06rdtcjr2chlhexm4lpl0";
        }
        {
          identity = ../secrets/pub/master-clone1.pub;
          pubkey = "age1yubikey1qwq4shht6jmgpdma3t0nkueqz2w2vfmtgq4jnj06rdtcjr2chlhexm4lpl0";
        }
        {
          identity = ../secrets/pub/master-clone2.pub;
          pubkey = "age1yubikey1qwq4shht6jmgpdma3t0nkueqz2w2vfmtgq4jnj06rdtcjr2chlhexm4lpl0";
        }
      ];
      extraEncryptionPubkeys = [ ]; # TODO: Backup key
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
