# Terranix: Cloudflare DNS as code, applied with OpenTofu (infra/dns/README.md).
#
# Environment-scoped, not per-host: every environment with dns.publicIPv4 set
# instantiates its `terranix` class (the records module in ./dns.nix) into
# flake.terranixModules.<env>. Hosts and clusters expose their `service-domains`
# emissions up to the environment so the records module sees all of them.
#
#   nix build .#dns.config   — config.tf.json
#   dns-adopt / dns-plan / dns-apply (devshell)
{
  den,
  inputs,
  lib,
  config,
  ...
}:
let
  inherit (den.lib.policy) pipe;

  # ponytail: one environment publishes DNS; key configs by env if a second sets dns.publicIPv4.
  dnsEnv = "prod";
  workdir = "infra/dns";
  terranixModules = config.flake.terranixModules.${dnsEnv};
in
{
  flake-file.inputs.terranix = {
    url = "github:terranix/terranix";
    inputs = {
      nixpkgs.follows = "nixpkgs-unstable";
      flake-parts.follows = "flake-parts";
      import-tree.follows = "import-tree";
      systems.follows = "systems";
    };
  };

  imports = [ inputs.terranix.flakeModule ];

  den.classes.terranix.description = "Terranix (OpenTofu) modules collected per environment";

  den.policies.expose-service-domains = _: [ (pipe.from "service-domains" [ pipe.expose ]) ];

  den.policies.env-to-terranix =
    { environment, ... }:
    lib.optionals (environment.dns.publicIPv4 != null) [
      (den.lib.policy.instantiate {
        name = "${environment.name}-dns";
        class = "terranix";
        instantiate = { modules, ... }: modules;
        intoAttr = [
          "terranixModules"
          environment.name
        ];
      })
    ];

  den.schema.host.includes = [ den.policies.expose-service-domains ];
  den.schema.cluster.includes = [ den.policies.expose-service-domains ];
  den.schema.environment.includes = [
    den.aspects.dns-records
    den.policies.env-to-terranix
  ];

  perSystem =
    { config, pkgs, ... }:
    let
      tf = config.terranix.terranixConfigurations.dns;
      inherit (tf.result) scripts terraformConfiguration;

      # Declared records as [{ address, name, type, zone }] for dns-adopt.
      declared = pkgs.writeText "dns-declared.json" (
        builtins.toJSON terraformConfiguration._meta.records
      );

      # Decrypts the Cloudflare token and the state passphrase into this process's
      # env only. Run from the repo root (the terranix scripts cd into ${workdir}).
      secretsPrelude = ''
        cd "$(git rev-parse --show-toplevel)"
        identity=$(mktemp)
        trap 'rm -f "$identity"' EXIT
        age-plugin-yubikey -i > "$identity"
        CLOUDFLARE_API_TOKEN=$(age -d -i "$identity" .secrets/env/${dnsEnv}/cloudflare-api-key.age)
        TF_VAR_state_passphrase=$(age -d -i "$identity" .secrets/env/${dnsEnv}/tofu-state-passphrase.age)
        export CLOUDFLARE_API_TOKEN TF_VAR_state_passphrase
      '';

      mkDnsCommand =
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
      terranix.exportDevShells = false;
      terranix.terranixConfigurations.dns = {
        inherit workdir;
        modules = terranixModules;
        # Providers come from nixpkgs, so `tofu init` never downloads one.
        terraformWrapper.package = pkgs.opentofu.withPlugins (p: [ p.cloudflare_cloudflare ]);
      };

      packages = {
        dns-plan = mkDnsCommand "dns-plan" "OpenTofu plan for the Cloudflare DNS records" [ ] ''
          ${lib.getExe scripts.plan}
        '';
        dns-apply =
          mkDnsCommand "dns-apply" "OpenTofu apply for the Cloudflare DNS records (asks to confirm)" [ ]
            ''
              ${lib.getExe scripts.apply}
            '';
        dns-adopt =
          mkDnsCommand "dns-adopt" "Write ${workdir}/imports.tf.json for records that already exist"
            [
              pkgs.curl
              pkgs.jq
            ]
            ''
              api=https://api.cloudflare.com/client/v4
              cf() { curl -fsS -H @<(printf 'Authorization: Bearer %s\n' "$CLOUDFLARE_API_TOKEN") "$api$1"; }

              existing='[]'
              for zone in $(jq -r '[.[].zone] | unique | .[]' ${declared}); do
                zone_id=$(cf "/zones?name=$zone" | jq -r '.result[0].id // empty')
                if [[ -z $zone_id ]]; then
                  echo "dns-adopt: zone $zone not visible to the token" >&2
                  exit 1
                fi
                # ponytail: one page of 5000 records per zone; paginate if a zone ever outgrows it.
                records=$(cf "/zones/$zone_id/dns_records?per_page=5000" \
                  | jq --arg zid "$zone_id" '[.result[] | {name, type, id: "\($zid)/\(.id)"}]')
                existing=$(jq -n --argjson a "$existing" --argjson b "$records" '$a + $b')
              done

              # A declared name held by a different type (e.g. a www CNAME) blocks the create.
              jq -r --argjson ex "$existing" '.[] as $d
                | $ex[] | select(.name == $d.name and .type != $d.type)
                | "dns-adopt: \(.name) exists as \(.type), declared \($d.type); resolve by hand"' \
                ${declared} >&2

              jq --argjson ex "$existing" '{ import: [ .[] as $d
                  | $ex[] | select(.name == $d.name and .type == $d.type)
                  | { to: $d.address, id } ] }' ${declared} > ${workdir}/imports.tf.json
              echo "dns-adopt: $(jq '.import | length' ${workdir}/imports.tf.json) of $(jq length ${declared}) declared records exist; wrote ${workdir}/imports.tf.json"
            '';
      };

      devshells.default.commands =
        map
          (name: {
            package = config.packages.${name};
            inherit name;
            help = config.packages.${name}.meta.description;
          })
          [
            "dns-adopt"
            "dns-plan"
            "dns-apply"
          ];
    };
}
