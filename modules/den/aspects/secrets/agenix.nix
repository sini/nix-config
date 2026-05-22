{ den, lib, inputs, self, ... }:
{
  den.aspects.secrets.agenix = {
    nixos =
      { config, host, ... }:
      {
        imports = [
          inputs.agenix.nixosModules.default
          inputs.agenix-rekey.nixosModules.default
        ];

        age = {
          # Agenix decrypts before impermanence creates mounts
          identityPaths = [
            "/persist/etc/ssh/ssh_host_ed25519_key"
          ];

          rekey = {
            inherit (inputs.self.secretsConfig) masterIdentities;
            storageMode = "local";
            hostPubkey = host.public_key;
            generatedSecretsDir = host.secretPath + "/generated";
            localStorageDir = host.secretPath + "/rekeyed";
          };
        };

        # Remove agenix directory before switching if it's a dir instead of link
        system.activationScripts = lib.mkIf (config.age.secrets != { }) {
          removeAgenixLink.text = "[[ ! -L /run/agenix ]] && [[ -d /run/agenix ]] && rm -rf /run/agenix";
          agenixNewGeneration.deps = [ "removeAgenixLink" ];
        };

        # Make secrets paths available as module arg
        _module.args.secrets = lib.mapAttrs (_: v: v.path) config.age.secrets;

        # Make agenix home-manager module available
        home-manager.sharedModules = [
          inputs.agenix.homeManagerModules.default
          inputs.agenix-rekey.homeManagerModules.default
          (
            { config, lib, ... }:
            {
              _module.args.secrets = lib.mapAttrs (_: v: v.path) config.age.secrets;
            }
          )
        ];
      };

    # HM-level agenix config
    homeManager =
      { inputs, config, osConfig, host, lib, ... }:
      {
        age = {
          identityPaths = lib.optionals (osConfig.age.secrets ? "user-identity-${config.home.username}") [
            osConfig.age.secrets."user-identity-${config.home.username}".path
          ];

          rekey = {
            inherit (inputs.self.secretsConfig) masterIdentities;
            storageMode = "local";
            generatedSecretsDir =
              self + "/.secrets/generated/${config.home.username}/${osConfig.networking.hostName}";
            localStorageDir =
              self + "/.secrets/rekeyed/${config.home.username}/${osConfig.networking.hostName}";
            hostPubkey =
              if (osConfig.age.secrets ? "user-identity-${config.home.username}") then
                (self + "/.secrets/users/${config.home.username}/id_agenix.pub")
              else
                host.public_key;
          };
        };
      };

    persist = {
      # Agenix-rekey generators state
    };
  };
}
