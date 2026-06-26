# Agenix battery: imports agenix + agenix-rekey modules per host class,
# configures age.rekey from scope context, handles HM agenix wiring,
# and imports custom generators.
#
# Fires at host scope via den.schema.host.includes. Receives secretsConfig
# from fleet scope context (propagated through scope inheritance).
{
  den,
  inputs,
  rootPath,
  lib,
  ...
}:
let
  agenixGeneratorsModule = import ../aspects/secrets/_generators-module.nix;

  # agenix ships nixos/darwin/homeManager modules only; there is no
  # droidModules. nix-on-droid has no system-level agenix integration, so the
  # droid branch skips the system agenix module and system age config, but still
  # imports the agenix homeManager modules into home-manager.sharedModules so the
  # bridged home-manager.config gains the `age` option (the per-user agenix
  # config emitted by agenixUserAspect rides there).
  agenixHostAspect =
    { host, secretsConfig, ... }:
    let
      hasImpermanence = host.hasAspect den.aspects.core.impermanence;
      persistPrefix = lib.optionalString hasImpermanence "/persist";
    in
    {
      name = "agenix/${host.name}";
      ${host.class} =
        if host.class == "droid" then
          {
            home-manager.sharedModules = [
              inputs.agenix.homeManagerModules.default
              inputs.agenix-rekey.homeManagerModules.default
              agenixGeneratorsModule
              (
                { config, lib, ... }:
                {
                  _module.args.secrets = lib.mapAttrs (_: v: v.path) config.age.secrets;
                }
              )
            ];
          }
        else
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
                "${persistPrefix}/etc/ssh/ssh_host_ed25519_key"
              ];

              rekey = {
                inherit (secretsConfig) masterIdentities;
                storageMode = "local";
                hostPubkey = builtins.readFile host.public_key;
                generatedSecretsDir = host.secretPath + "/generated";
                localStorageDir = host.secretPath + "/rekeyed";
              };

              # Per-user identity secrets are emitted by agenixUserAspect at user scope
            };

            # Remove agenix directory before switching if it's a dir instead of link
            system.activationScripts = lib.mkIf (host.class == "nixos" && config.age.secrets != { }) {
              removeAgenixLink.text = "[[ ! -L /run/agenix ]] && [[ -d /run/agenix ]] && rm -rf /run/agenix";
              agenixNewGeneration.deps = [ "removeAgenixLink" ];
            };

            # Make secrets paths available as module arg
            _module.args.secrets = lib.mapAttrs (_: v: v.path) config.age.secrets;

            # Make agenix home-manager module available
            home-manager.sharedModules = [
              inputs.agenix.homeManagerModules.default
              inputs.agenix-rekey.homeManagerModules.default
              agenixGeneratorsModule
              (
                { config, lib, ... }:
                {
                  _module.args.secrets = lib.mapAttrs (_: v: v.path) config.age.secrets;
                }
              )
            ];
          };
    };
  # At cluster scope, bridge age-secrets quirk data into the k8s-manifests
  # class. Den's wrapClassModule binds the age-secrets pipe data (post-
  # assemblePipes) into this function, which returns it as a nixidy module.
  # This mirrors how agenixHostAspect bridges agenix into the host's class.
  agenixClusterAspect = {
    name = "agenix/cluster";
    k8s-manifests =
      {
        age-secrets ? [ ],
        ...
      }:
      {
        imports = age-secrets;
      };
  };

  agenixUserAspect =
    {
      user,
      host,
      secretsConfig,
      ...
    }:
    {
      name = "agenix-identity/${user.name}@${host.name}";
      # droid has no system agenix module (see agenixHostAspect note), so the
      # per-user system identity secret is skipped there.
      ${host.class} =
        if host.class == "droid" then
          (_: { })
        else
          _: {
            age.secrets."user-identity-${user.name}" = {
              rekeyFile = rootPath + "/.secrets/users/${user.name}/id_agenix.age";
              owner = user.name;
              group = user.name;
              mode = "600";
              generator.script = "age-identity";
            };
          };
      homeManager =
        { osConfig, ... }:
        let
          # On droid osConfig (nix-on-droid) has no `age` option; there is no
          # system identity secret and no provisioned host SSH key, so fall back
          # to the per-user agenix pubkey path. agenix-rekey reads hostPubkey
          # lazily (only when secrets actually need rekeying), so passing a path
          # that may not yet exist is safe for a secret-less tablet.
          hasOsAge = osConfig ? age;
          hasUserIdentity = hasOsAge && osConfig.age.secrets ? "user-identity-${user.name}";
          userPubkeyPath = rootPath + "/.secrets/users/${user.name}/id_agenix.pub";
        in
        {
          age = {
            identityPaths = lib.optionals hasUserIdentity [
              osConfig.age.secrets."user-identity-${user.name}".path
            ];

            rekey = {
              inherit (secretsConfig) masterIdentities;
              storageMode = "local";
              generatedSecretsDir = rootPath + "/.secrets/generated/${user.name}/${host.name}";
              localStorageDir = rootPath + "/.secrets/rekeyed/${user.name}/${host.name}";
              hostPubkey =
                if hasUserIdentity then
                  userPubkeyPath
                else if hasOsAge then
                  osConfig.age.rekey.hostPubkey
                else
                  userPubkeyPath;
            };
          };
        };
    };
in
{
  flake-file.inputs = {
    agenix = {
      url = "github:ryantm/agenix";
      inputs.home-manager.follows = "home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    agenix-rekey = {
      url = "github:sini/agenix-rekey/feat/settings";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    agenix-rekey-to-sops = {
      url = "github:sini/agenix-rekey-to-sops";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.agenix-rekey.follows = "agenix-rekey";
    };
  };

  imports = [
    inputs.agenix-rekey.flakeModule
    inputs.agenix-rekey-to-sops.flakeModule
  ];

  den.schema.host.includes = [ agenixHostAspect ];
  den.schema.user.includes = [ agenixUserAspect ];
  den.schema.cluster.includes = [ agenixClusterAspect ];

  perSystem =
    {
      config,
      pkgs,
      system,
      ...
    }:
    {
      agenix-rekey = {
        nixosConfigurations = inputs.self.outputs.nixosConfigurations;
        darwinConfigurations = inputs.self.outputs.darwinConfigurations;
        collectHomeManagerConfigurations = true;
        extraConfigurations = inputs.self.nixidyEnvs.${system} or { };
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
            name = "AGENIX_REKEY_ADD_TO_GIT";
            value = "true";
          }
          {
            name = "SOPS_AGE_KEY_CMD";
            value = "age-plugin-yubikey -i";
          }
        ];
      };
    };
}
