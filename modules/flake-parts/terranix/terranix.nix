# Terranix: Cloudflare DNS as code, applied with OpenTofu (infra/dns/README.md).
#
# One workspace and one state for every managed zone. The edge environment (the
# one with dns.publicIPv4) instantiates its `terranix` class (the records module
# in ./dns.nix) into flake.terranixModules.dns; it collects every domain's zones
# and records and every host's and cluster's `served-domains` record
# (policies/pipes.nix, env-collect-dns), which the records module takes as
# arguments.
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
  workdir = "infra/dns";
  terranixModules = config.flake.terranixModules.dns;

  # The API token for each Cloudflare account a domain names in dns.cloudflare.
  cloudflareTokens.json64 = ".secrets/env/prod/cloudflare-api-key.age";
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

  den.policies.env-to-terranix =
    { environment, ... }:
    lib.optionals (environment.dns.publicIPv4 != null) [
      (den.lib.policy.instantiate {
        name = "${environment.name}-dns";
        class = "terranix";
        instantiate = { modules, ... }: modules;
        # ponytail: one edge environment; a second one with dns.publicIPv4 collides here.
        intoAttr = [
          "terranixModules"
          "dns"
        ];
      })
    ];

  den.schema.environment.includes = [
    den.aspects.dns-records
    den.policies.env-to-terranix
  ];

  perSystem =
    { config, pkgs, ... }:
    let
      tf = config.terranix.terranixConfigurations.dns;
      inherit (tf.result) scripts terraformConfiguration;

      inherit (terraformConfiguration) _meta;
      tofu = lib.getExe tf.result.terraformWrapper;

      # Declared records as [{ address, name, type, content, zone }] for dns-adopt.
      declared = pkgs.writeText "dns-declared.json" (builtins.toJSON _meta.records);

      # Decrypts the Cloudflare token and the state passphrase into this process's
      # env only. Run from the repo root (the terranix scripts cd into ${workdir}).
      secretsPrelude = ''
        cd "$(git rev-parse --show-toplevel)"
        identity=$(mktemp)
        trap 'rm -f "$identity"' EXIT
        age-plugin-yubikey -i > "$identity"
        CLOUDFLARE_API_TOKEN=$(age -d -i "$identity" ${cloudflareTokens.${_meta.account}})
        TF_VAR_state_passphrase=$(age -d -i "$identity" .secrets/env/${_meta.environment}/tofu-state-passphrase.age)
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
                  | jq --arg zid "$zone_id" '[.result[] | {name, type, content, rid: .id, id: "\($zid)/\(.id)"}]')
                existing=$(jq -n --argjson a "$existing" --argjson b "$records" '$a + $b')
              done

              # Records already in state, by Cloudflare record id. The previous
              # import blocks may name addresses this config no longer declares,
              # so they are set aside while the state is read.
              imports=${workdir}/imports.tf.json
              if [[ -e $imports ]]; then mv "$imports" "$imports.prev"; fi
              trap 'rm -f "$identity"; if [[ -e $imports.prev ]]; then mv "$imports.prev" "$imports"; fi' EXIT
              ${lib.getExe scripts.init} >&2
              state=$(${tofu} show -json | jq '[.values.root_module.resources[]? | select(.type == "cloudflare_dns_record") | {address, rid: .values.id}]')

              # A CNAME cannot share its name with another type: that blocks the create.
              jq -r --argjson ex "$existing" '.[] as $d
                | $ex[] | select(.name == $d.name and .type != $d.type and (.type == "CNAME" or $d.type == "CNAME"))
                | "dns-adopt: \(.name) exists as \(.type), declared \($d.type); resolve by hand"' \
                ${declared} >&2

              # Several records share a name, so a live record matches on name, type
              # and content. One already in state under another address moves; one
              # not in state is imported.
              jq --argjson ex "$existing" --argjson st "$state" '
                [ .[] as $d | $ex[] | select(.name == $d.name and .type == $d.type and .content == $d.content)
                  | . as $e | { to: $d.address, id: $e.id, from: ([ $st[] | select(.rid == $e.rid) | .address ] | first) } ]
                | { import: [ .[] | select(.from == null) | { to, id } ],
                    moved: [ .[] | select(.from != null and .from != .to) | { from, to } ] }' \
                ${declared} > "$imports.new"
              mv "$imports.new" "$imports"
              rm -f "$imports.prev"
              echo "dns-adopt: $(jq length ${declared}) declared; $(jq '.import | length' "$imports") to import, $(jq '.moved | length' "$imports") to move; wrote $imports"
            '';
      };

      # Each devshell command re-evaluates the working tree on every call (like
      # nixidy-sync), so an edit is planned without reloading the devshell.
      devshells.default.commands =
        map
          (name: {
            inherit name;
            help = config.packages.${name}.meta.description;
            command = ''exec nix run "$(git rev-parse --show-toplevel)#${name}" -- "$@"'';
          })
          [
            "dns-adopt"
            "dns-plan"
            "dns-apply"
          ];
    };
}
