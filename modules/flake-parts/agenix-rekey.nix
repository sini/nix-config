# Based on: https://github.com/oddlama/nix-config/blob/7ccd7856eed93d2ba5b011d6211ff7c4f03a75f0/nix/agenix-rekey.nix
{
  self,
  inputs,
  rootPath,
  ...
}:
{
  imports = [
    inputs.agenix-rekey.flakeModule
    inputs.agenix-rekey-to-sops.flakeModule
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
      pkgs,
      system,
      ...
    }:
    {
      agenix-rekey = {
        nixosConfigurations = self.nodes;
        collectHomeManagerConfigurations = true;
        extraConfigurations = self.nixidyEnvs.${system} or { };
      };

      devshells.default = {
        packages = [
          pkgs.age
          pkgs.age-plugin-yubikey
        ];
        commands = [
          {
            inherit (config.agenix-rekey-sops) package;
            help = "Edit, generate, rekey secrets, and generate SOPS files";
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
