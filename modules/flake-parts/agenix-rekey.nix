# Based on: https://github.com/oddlama/nix-config/blob/7ccd7856eed93d2ba5b011d6211ff7c4f03a75f0/nix/agenix-rekey.nix
{
  inputs,
  self,
  rootPath,
  ...
}:
{
  imports = [
    inputs.agenix-rekey.flakeModule
  ];

  flake.agenix-rekey = inputs.agenix-rekey.configure {
    userFlake = self;
    inherit (self) nixosConfigurations;
  };

  flake.secretsConfig = {
    masterIdentities = [
      (rootPath + "/secrets/pub/master.pub")
      (rootPath + "/secrets/pub/master-clone1.pub")
      (rootPath + "/secrets/pub/master-clone2.pub")
    ];
    extraEncryptionPubkeys = [ ];
  };

  perSystem =
    { inputs', pkgs, ... }:
    {
      devshells.default = {
        packages = [
          pkgs.age
          pkgs.age-plugin-yubikey
          inputs'.agenix-rekey.packages.default
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
