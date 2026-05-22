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
            hostPubkey = builtins.readFile host.public_key;
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

        # Make agenix home-manager module available + configure per-user rekey
        home-manager.sharedModules = [
          inputs.agenix.homeManagerModules.default
          inputs.agenix-rekey.homeManagerModules.default
          (
            { config, osConfig, lib, ... }:
            {
              _module.args.secrets = lib.mapAttrs (_: v: v.path) config.age.secrets;

              age = {
                identityPaths = lib.optionals (osConfig.age.secrets ? "user-identity-${config.home.username}") [
                  osConfig.age.secrets."user-identity-${config.home.username}".path
                ];

                rekey = {
                  masterIdentities = [
                    (self + "/.secrets/pub/master.pub")
                    (self + "/.secrets/pub/master-clone1.pub")
                    (self + "/.secrets/pub/master-clone2.pub")
                  ];
                  storageMode = "local";
                  generatedSecretsDir =
                    self + "/.secrets/generated/${config.home.username}/${osConfig.networking.hostName}";
                  localStorageDir =
                    self + "/.secrets/rekeyed/${config.home.username}/${osConfig.networking.hostName}";
                  hostPubkey =
                    if (osConfig.age.secrets ? "user-identity-${config.home.username}") then
                      (self + "/.secrets/users/${config.home.username}/id_agenix.pub")
                    else
                      osConfig.age.rekey.hostPubkey;
                };
              };
            }
          )
        ];
      };

    # HM-level agenix config
    homeManager =
      { config, osConfig, host, lib, ... }:
      {
        age = {
          identityPaths = lib.optionals (osConfig.age.secrets ? "user-identity-${config.home.username}") [
            osConfig.age.secrets."user-identity-${config.home.username}".path
          ];

          rekey = {
            masterIdentities = [
              (self + "/.secrets/pub/master.pub")
              (self + "/.secrets/pub/master-clone1.pub")
              (self + "/.secrets/pub/master-clone2.pub")
            ];
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
