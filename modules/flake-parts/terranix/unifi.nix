# Terranix: the UniFi gateway as code, applied with OpenTofu (infra/unifi/README.md).
#
# A separate workspace and state from DNS (./terranix.nix). Every environment
# with `unifi` set instantiates its `unifi-terranix` class into
# flake.unifiTerranixModules.<env>. The gateway is one device and one UniFi
# site for prod and dev alike, so exactly one environment may set `unifi`.
#
#   nix build .#unifi.config   — config.tf.json
#   unifi-adopt / unifi-plan / unifi-apply (devshell)
{
  den,
  lib,
  config,
  ...
}:
let
  inherit (lib) mkOption types;

  # ponytail: one environment owns the gateway; key configs by env if a second controller appears.
  unifiEnv = "prod";
  workdir = "infra/unifi";
  unifiTerranixModules = config.flake.unifiTerranixModules.${unifiEnv};
in
{
  den.schema.environment.imports = [
    {
      options.unifi = mkOption {
        default = null;
        description = ''
          The UniFi gateway this environment manages, as OpenTofu state in infra/unifi.
          The controller is the gateway itself, https://<networks.default.gatewayIp>.
          null = this environment manages no UniFi resources.
        '';
        type = types.nullOr (
          types.submodule {
            options = {
              site = mkOption {
                type = types.str;
                default = "default";
                description = "UniFi site name (the API's internal reference, not its display name)";
              };
              bgp = {
                enabled = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Run the gateway's BGP daemon";
                };
                config = mkOption {
                  type = types.str;
                  description = "Raw FRR bgpd configuration, byte for byte as the controller stores it";
                };
                description = mkOption {
                  type = types.str;
                  description = "The controller's description of the BGP configuration";
                };
                uploadFileName = mkOption {
                  type = types.str;
                  description = "The file name the controller records for the uploaded configuration";
                };
              };
            };
          }
        );
      };
    }
  ];

  den.classes.unifi-terranix.description = "Terranix (OpenTofu) modules for the UniFi gateway, per environment";

  den.policies.env-to-unifi-terranix =
    { environment, ... }:
    lib.optionals (environment.unifi != null) [
      (den.lib.policy.instantiate {
        name = "${environment.name}-unifi";
        class = "unifi-terranix";
        instantiate = { modules, ... }: modules;
        intoAttr = [
          "unifiTerranixModules"
          environment.name
        ];
      })
    ];

  den.schema.environment.includes = [
    den.aspects.unifi-gateway
    den.policies.env-to-unifi-terranix
  ];

  den.aspects.unifi-gateway.unifi-terranix =
    { environment, ... }:
    let
      inherit (environment) unifi;
    in
    {
      terraform = {
        required_providers.unifi = {
          source = "ubiquiti-community/unifi";
          version = "0.56.1";
        };
        backend.local.path = "terraform.tfstate";
        encryption = {
          key_provider.pbkdf2.state.passphrase = "\${var.state_passphrase}";
          method.aes_gcm.state.keys = "\${key_provider.pbkdf2.state}";
          state = {
            method = "method.aes_gcm.state"; # a bare reference, not an interpolation
            enforced = true;
          };
          plan = {
            method = "method.aes_gcm.state"; # a bare reference, not an interpolation
            enforced = true;
          };
        };
      };

      variable.state_passphrase = {
        type = "string";
        sensitive = true;
        description = "State and plan encryption passphrase (TF_VAR_state_passphrase)";
      };

      # Key from UNIFI_API_KEY. The gateway serves a self-signed certificate.
      provider.unifi = {
        api_url = "https://${environment.networks.default.gatewayIp}";
        inherit (unifi) site;
        allow_insecure = true;
      };

      resource.unifi_bgp.${environment.name} = {
        inherit (unifi.bgp) enabled config description;
        upload_file_name = unifi.bgp.uploadFileName;
      };

      # Read by unifi-adopt.
      _meta = {
        api_url = "https://${environment.networks.default.gatewayIp}";
        inherit (unifi) site;
        bgp = "unifi_bgp.${environment.name}";
      };
    };

  # The unifi workspace's state passphrase, declared like dns-state-passphrase.
  den.aspects.unifi-state-passphrase.age-secrets =
    { environment, ... }:
    {
      age.secrets.unifi-state-passphrase = {
        rekeyFile = environment.secretPath + "/unifi-state-passphrase.age";
        intermediary = true;
        generator.script = "rfc3986-secret";
      };
    };

  perSystem =
    { config, pkgs, ... }:
    let
      tf = config.terranix.terranixConfigurations.unifi;
      inherit (tf.result) scripts terraformConfiguration;
      meta = pkgs.writeText "unifi-meta.json" (builtins.toJSON terraformConfiguration._meta);

      # Decrypts the API key and the state passphrase into this process's env only.
      secretsPrelude = ''
        cd "$(git rev-parse --show-toplevel)"
        identity=$(mktemp)
        trap 'rm -f "$identity"' EXIT
        age-plugin-yubikey -i > "$identity"
        UNIFI_API_KEY=$(age -d -i "$identity" .secrets/env/${unifiEnv}/unifi-api-key.age)
        TF_VAR_state_passphrase=$(age -d -i "$identity" .secrets/env/${unifiEnv}/unifi-state-passphrase.age)
        export UNIFI_API_KEY TF_VAR_state_passphrase
      '';

      mkUnifiCommand =
        name: description: runtimeInputs: text:
        pkgs.writeShellApplication {
          inherit name;
          meta.description = description;
          runtimeInputs = [
            pkgs.age
            pkgs.age-plugin-yubikey
            pkgs.git
          ]
          ++ runtimeInputs;
          text = secretsPrelude + text;
        };
    in
    {
      terranix.terranixConfigurations.unifi = {
        inherit workdir;
        modules = unifiTerranixModules;
        terraformWrapper.package = pkgs.opentofu.withPlugins (p: [ p.ubiquiti-community_unifi ]);
      };

      packages = {
        unifi-plan = mkUnifiCommand "unifi-plan" "OpenTofu plan for the UniFi gateway" [ ] ''
          ${lib.getExe scripts.plan}
        '';
        unifi-apply =
          mkUnifiCommand "unifi-apply" "OpenTofu apply for the UniFi gateway (asks to confirm)" [ ]
            ''
              ${lib.getExe scripts.apply}
            '';
        unifi-adopt =
          mkUnifiCommand "unifi-adopt" "Write ${workdir}/imports.tf.json for the live UniFi objects"
            [
              pkgs.curl
              pkgs.jq
            ]
            ''
              api=$(jq -r .api_url ${meta})
              site=$(jq -r .site ${meta})
              # GET only. -k: the gateway's certificate is self-signed.
              bgp=$(curl -fksS -H @<(printf 'X-Api-Key: %s\n' "$UNIFI_API_KEY") \
                "$api/proxy/network/v2/api/site/$site/bgp/config")
              if [[ $(jq length <<<"$bgp") != 1 ]]; then
                echo "unifi-adopt: site $site has no BGP configuration to adopt" >&2
                exit 1
              fi
              # unifi_bgp is a per-site singleton; its import id is the site name.
              jq --arg site "$site" '{ import: [ { to: .bgp, id: $site } ] }' ${meta} > ${workdir}/imports.tf.json
              echo "unifi-adopt: site $site BGP config $(jq -r '.[0]._id' <<<"$bgp") ($(jq -r '.[0].description' <<<"$bgp")); wrote ${workdir}/imports.tf.json"
            '';
      };

      devshells.default.commands =
        map
          (name: {
            inherit name;
            help = config.packages.${name}.meta.description;
            command = ''exec nix run "$(git rev-parse --show-toplevel)#${name}" -- "$@"'';
          })
          [
            "unifi-adopt"
            "unifi-plan"
            "unifi-apply"
          ];
    };
}
