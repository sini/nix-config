# Agenix battery: imports agenix + agenix-rekey modules per host class,
# configures age.rekey from scope context, handles HM agenix wiring,
# and imports custom generators.
#
# Fires at host scope via den.schema.host.includes. Receives secretsConfig
# from fleet scope context (propagated through scope inheritance).
{
  inputs,
  self,
  ...
}:
let
  agenixGeneratorsModule = import ../aspects/secrets/_generators-module.nix;

  agenixHostAspect =
    { host, secretsConfig, ... }:
    {
      name = "agenix/${host.name}";
      ${host.class} =
        { config, lib, ... }:
        {
          imports = [
            inputs.agenix."${host.class}Modules".default
            inputs.agenix-rekey."${host.class}Modules".default
            agenixGeneratorsModule
          ];

          age = {
            # Agenix decrypts before impermanence creates mounts
            identityPaths = [
              "/persist/etc/ssh/ssh_host_ed25519_key"
            ];

            rekey = {
              inherit (secretsConfig) masterIdentities;
              storageMode = "local";
              hostPubkey = builtins.readFile host.public_key;
              generatedSecretsDir = host.secretPath + "/generated";
              localStorageDir = host.secretPath + "/rekeyed";
            };
          };

          # Remove agenix directory before switching if it's a dir instead of link
          system.activationScripts = lib.mkIf (host.class == "nixos" && config.age.secrets != { }) {
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
              {
                config,
                osConfig,
                lib,
                ...
              }:
              {
                _module.args.secrets = lib.mapAttrs (_: v: v.path) config.age.secrets;

                age = {
                  identityPaths = lib.optionals (osConfig.age.secrets ? "user-identity-${config.home.username}") [
                    osConfig.age.secrets."user-identity-${config.home.username}".path
                  ];

                  rekey = {
                    inherit (secretsConfig) masterIdentities;
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
    };
in
{
  den.schema.host.includes = [ agenixHostAspect ];
}
