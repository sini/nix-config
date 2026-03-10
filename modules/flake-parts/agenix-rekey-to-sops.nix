# Based on: https://github.com/oddlama/nix-config/blob/7ccd7856eed93d2ba5b011d6211ff7c4f03a75f0/nix/agenix-rekey.nix
{
  self,
  inputs,
  rootPath,
  ...
}:
{
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
      pkgs,
      system,
      ...
    }:
    let
      agenixApps = inputs.agenix-rekey-to-sops.configure {
        userFlake = self;
        nixosConfigurations = self.nodes;
        collectHomeManagerConfigurations = true;
        # Flatten the nested nixidyEnvs structure for all systems
        extraConfigurations = self.nixidyEnvs.${system} or { };
      };
    in
    {
      # Expose agenix-rekey apps
      apps = {
        agenix-rekey = agenixApps.${system}.rekey;
        agenix-generate = agenixApps.${system}.generate;
        agenix-edit = agenixApps.${system}.edit-view;
        agenix-sops-rekey = agenixApps.${system}.sops-rekey;
      };

      devshells.default = {
        packages = [
          pkgs.age
          pkgs.age-plugin-yubikey
        ];
        commands = [
          {
            package = agenixApps.${system}.rekey;
            help = "Rekey all secrets";
          }
          {
            package = agenixApps.${system}.generate;
            help = "Generate missing secrets";
          }
          {
            package = agenixApps.${system}.edit-view;
            help = "Edit a secret";
          }
          {
            package = agenixApps.${system}.sops-rekey;
            help = "Generate SOPS-encrypted secrets";
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
