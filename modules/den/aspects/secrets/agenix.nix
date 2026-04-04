{
  den,
  inputs,
  lib,
  rootPath,
  ...
}:
{
  den.aspects.agenix = {
    includes = lib.attrValues den.aspects.agenix._ ++ [
      den.aspects.agenix-generators
    ];

    _ = {
      # Import agenix NixOS modules
      nixosModule = den.lib.perHost {
        nixos = {
          imports = [
            inputs.agenix.nixosModules.default
            inputs.agenix-rekey.nixosModules.default
          ];
        };
      };

      # Core agenix configuration
      config = den.lib.perHost (
        { host }:
        {
          nixos =
            {
              config,
              lib,
              ...
            }:
            let
              secretPath = rootPath + "/.secrets/hosts/${host.name}";
            in
            {
              age = {
                # Agenix decrypts before impermanence creates mounts, so use /persist path
                identityPaths = [
                  "/persist/etc/ssh/ssh_host_ed25519_key"
                ];

                rekey = {
                  inherit (inputs.self.secretsConfig) masterIdentities;
                  storageMode = "local";
                  hostPubkey = host.public_key or (secretPath + "/ssh_host_ed25519_key.pub");
                  generatedSecretsDir = secretPath + "/generated";
                  localStorageDir = secretPath + "/rekeyed";
                };
              };

              # Remove stale agenix directory before activation
              system.activationScripts = lib.mkIf (config.age.secrets != { }) {
                removeAgenixLink.text = "[[ ! -L /run/agenix ]] && [[ -d /run/agenix ]] && rm -rf /run/agenix";
                agenixNewGeneration.deps = [ "removeAgenixLink" ];
              };

              # Make secrets paths available as a module arg
              _module.args.secrets = lib.mapAttrs (_: v: v.path) config.age.secrets;

              # HM agenix modules injected via hm-host context (see below)
            };
        }
      );
    };
  };

  # Inject agenix HM modules via hm-host context (only for hosts with HM users)
  den.ctx.hm-host.includes = [
    {
      nixos.home-manager.sharedModules = [
        inputs.agenix.homeManagerModules.default
        inputs.agenix-rekey.homeManagerModules.default
        (
          { config, lib, ... }:
          {
            _module.args.secrets = lib.mapAttrs (_: v: v.path) config.age.secrets;
            age.rekey = {
              inherit (inputs.self.secretsConfig) masterIdentities;
              storageMode = "local";
            };
          }
        )
      ];
    }
  ];
}
