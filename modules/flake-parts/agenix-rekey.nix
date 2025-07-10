# Based on: https://github.com/oddlama/nix-config/blob/7ccd7856eed93d2ba5b011d6211ff7c4f03a75f0/nix/agenix-rekey.nix
{
  inputs,
  rootPath,
  ...
}:
{
  imports = [
    inputs.agenix-rekey.flakeModule
  ];

  flake.secretsConfig = {
    masterIdentities = [
      (rootPath + "/.secrets/pub/master.pub")
      (rootPath + "/.secrets/pub/master-clone1.pub")
      (rootPath + "/.secrets/pub/master-clone2.pub")
    ];
    extraEncryptionPubkeys = [ ];
  };

  perSystem =
    {
      config,
      # inputs',
      pkgs,
      ...
    }:
    {
      devshells.default = {
        packages = [
          pkgs.age
          pkgs.age-plugin-yubikey
          # inputs'.agenix-rekey.packages.default
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
