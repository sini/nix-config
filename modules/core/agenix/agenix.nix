{
  inputs,
  rootPath,
  ...
}:
{
  flake.features.agenix = {
    requires = [ "agenix-generators" ];
    system =
      {
        config,
        host,
        users,
        lib,
        ...
      }:
      {
        imports = [
          inputs.agenix.nixosModules.default
          inputs.agenix-rekey.nixosModules.default
        ];

        # Agenix decrypts before impermanence creates mounts so we have to get key
        # from persist
        age = {
          # Agenix decrypts before impermanence creates mounts so we have to get key
          # from persist
          identityPaths = [
            "${lib.optionalString config.impermanence.enable "/persist"}/etc/ssh/ssh_host_ed25519_key"
          ];

          rekey = {
            inherit (inputs.self.secretsConfig) masterIdentities;
            storageMode = "local";
            hostPubkey = host.public_key;
            generatedSecretsDir = rootPath + "/.secrets/generated/${config.networking.hostName}";
            localStorageDir = rootPath + "/.secrets/rekeyed/${config.networking.hostName}";
          };

          # Create age secrets for each enabled user if their id_agenix.pub exists
          secrets = lib.mkMerge [
            (lib.mapAttrs' (username: _: {
              name = "user-identity-${username}";
              value = {
                rekeyFile = rootPath + "/.secrets/users/${username}/id_agenix.age";
                owner = username;
                group = username;
                mode = "600";
                generator.script = "age-identity";
              };
            }) users) # We create age identities for
          ];
        };

        # Just before switching, remove the agenix directory if it exists.
        # This can happen when a secret is used in the initrd because it will
        # then be copied to the initramfs under the same path. This materializes
        # /run/agenix as a directory which will cause issues when the actual system tries
        # to create a link called /run/agenix. Agenix should probably fail in this case,
        # but doesn't and instead puts the generation link into the existing directory.
        # See https://github.com/ryantm/agenix/pull/187.
        system.activationScripts = lib.mkIf (config.age.secrets != { }) {
          removeAgenixLink.text = "[[ ! -L /run/agenix ]] && [[ -d /run/agenix ]] && rm -rf /run/agenix";
          agenixNewGeneration.deps = [ "removeAgenixLink" ];
        };

        # Make agenix home-manager module available to all users
        home-manager.sharedModules = [
          inputs.agenix.homeManagerModules.default
          inputs.agenix-rekey.homeManagerModules.default
        ];
      };

    home =
      {
        config,
        osConfig,
        host,
        lib,
        ...
      }:
      {
        age = {
          identityPaths = lib.optionals (osConfig.age.secrets ? "user-identity-${config.home.username}") [
            osConfig.age.secrets."user-identity-${config.home.username}".path
          ];

          rekey = {
            inherit (inputs.self.secretsConfig) masterIdentities;

            storageMode = "local";

            generatedSecretsDir =
              rootPath + "/.secrets/generated/${config.home.username}/${osConfig.networking.hostName}";

            localStorageDir =
              rootPath + "/.secrets/rekeyed/${config.home.username}/${osConfig.networking.hostName}";

            hostPubkey =
              if (osConfig.age.secrets ? "user-identity-${config.home.username}") then
                (rootPath + "/.secrets/users/${config.home.username}/id_agenix.pub")
              else
                host.public_key;
          };
        };
      };
  };
}
