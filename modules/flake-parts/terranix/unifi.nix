# Terranix: the UniFi gateway as code, applied with OpenTofu (infra/unifi/README.md).
#
# A separate workspace and state from DNS (./terranix.nix). Every environment
# with `unifi` set instantiates its `unifi-terranix` class into
# flake.unifiTerranixModules.<env>. The gateway is one device and one UniFi
# site for prod and dev alike, so exactly one environment may set `unifi`.
#
#   nix build .#unifi.config   — config.tf.json
#   nix build .#checks.<system>.unifi-bgp-render
#   unifi-adopt / unifi-plan / unifi-apply (devshell)
{
  den,
  lib,
  config,
  ...
}:
let
  inherit (lib) mkOption types;
  inherit (den.lib.policy) pipe;

  # ponytail: one environment owns the gateway; key configs by env if a second controller appears.
  unifiEnv = "prod";
  workdir = "infra/unifi";
  # The gateway's port forwards as unifi-adopt read them, in the provider's
  # model: { <resource name> = { id; config; }; }. Raw adoption first; a later
  # change derives targets (the gateway VIP) instead of restating them.
  portForwardsFile = ../../../infra/unifi/port-forwards.json;
  portForwards = lib.optionalAttrs (builtins.pathExists portForwardsFile) (
    lib.importJSON portForwardsFile
  );
  unifiTerranixModules = config.flake.unifiTerranixModules.${unifiEnv};

  # The gateway's raw FRR bgpd config: one peer group per remote ASN, one
  # neighbor per bgp-peers record. Raw, not the provider's structured peers:
  # its template forces ebgp-requires-policy, redistribute connected,
  # next-hop-self, multihop and timers, and cannot set maximum-paths.
  renderBgpConfig =
    {
      name,
      cidr,
      asn,
      routerId,
      peers,
    }:
    assert lib.assertMsg (asn != null) "unifi: environment ${name} sets no networks.default.gatewayAsn";
    let
      neighbors = lib.sort (a: b: a.asn < b.asn || (a.asn == b.asn && a.ip < b.ip)) (
        map (
          p:
          if p.asn == asn then
            throw "unifi: bgp peer ${p.hostname} shares the gateway's AS ${toString asn}; the gateway runs eBGP only"
          else
            p
        ) (builtins.filter (p: p.ip != routerId) peers)
      );
      asns = lib.unique (map (p: p.asn) neighbors);
      group = a: "as${toString a}";
      groupLines =
        a:
        [
          " !"
          " neighbor ${group a} peer-group"
          " neighbor ${group a} remote-as ${toString a}"
          " neighbor ${group a} soft-reconfiguration inbound"
        ]
        ++ lib.concatMap (p: [
          " neighbor ${p.ip} peer-group ${group a}"
          " neighbor ${p.ip} description ${p.hostname}"
        ]) (builtins.filter (p: p.asn == a) neighbors);
    in
    lib.concatStringsSep "\n" (
      [
        "! -*- bgp -*-"
        "!"
        "! FRR BGP Configuration for Unifi Router"
        "! Environment: ${name}"
        "! Management Network: ${cidr}"
        "!"
        "frr defaults traditional"
        "!"
        "hostname edge-${name}"
        "password zebra"
        "!"
        "router bgp ${toString asn}"
        " bgp router-id ${routerId}"
        " no bgp ebgp-requires-policy"
        " bgp bestpath as-path multipath-relax"
        " maximum-paths 8"
      ]
      ++ lib.concatMap groupLines asns
      ++ [
        " !"
        " address-family ipv4 unicast"
      ]
      ++ map (a: "  neighbor ${group a} activate") asns
      ++ [
        " exit-address-family"
        "!"
        "line vty"
        "!"
        ""
      ]
    );
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

  # Every BGP host of this environment is a gateway peer. Only hosts emit bgp-peers.
  den.policies.env-collect-bgp-peers =
    { environment, ... }:
    [
      (pipe.from "bgp-peers" [
        (pipe.collectAll ({ host, ... }: host.environment == environment.name))
      ])
    ];

  den.schema.environment.includes = [
    den.policies.env-collect-bgp-peers
    den.aspects.unifi-gateway
    den.policies.env-to-unifi-terranix
  ];

  den.aspects.unifi-gateway.unifi-terranix =
    {
      environment,
      bgp-peers ? [ ],
      ...
    }:
    let
      inherit (environment) unifi;
      net = environment.networks.default;
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
        inherit (unifi.bgp) enabled description;
        config = renderBgpConfig {
          inherit (environment) name;
          inherit (net) cidr;
          asn = net.gatewayAsn;
          routerId = net.gatewayIp;
          peers = bgp-peers;
        };
        upload_file_name = unifi.bgp.uploadFileName;
      };

      resource.unifi_port_forward = lib.mapAttrs (_: pf: pf.config) portForwards;

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

      # A controller portforward object (rest/portforward) to the provider's
      # model, the inverse of its portForwardToModel: an attribute the controller
      # leaves empty is unset, so the adoption plan shows no change.
      portForwardModel = pkgs.writeText "unifi-port-forward.jq" ''
        def nz: if . == null or . == "" then null else . end;
        def compact: with_entries(select(.value != null));
        def key: ((.name | nz) // ._id) | ascii_downcase | gsub("[^a-z0-9]+"; "_") | gsub("^_|_$"; "")
          | if test("^[0-9]") then "pf_" + . else . end;
        map({
          key: key,
          value: {
            id: ._id,
            config: ({
              name: (.name | nz),
              protocol: .proto,
              enabled: (if .enabled then null else false end),
              logging: (if .log then true else null end),
              wan: (if (.pfwd_interface | nz) or (.destination_ip | nz) or (.dst_port | nz)
                then { interface: (.pfwd_interface | nz), ip_address: (.destination_ip | nz), port: (.dst_port | nz) } | compact
                else null end),
              forward: (if (.fwd | nz) or (.fwd_port | nz)
                then { ip: (.fwd | nz), port: (.fwd_port | nz) } | compact
                else null end),
              source_limiting: (if .src_limiting_enabled or (.src_firewall_group_id | nz) or ((.src | nz) and .src != "any")
                then { ip: (.src | nz), firewall_group_id: (.src_firewall_group_id | nz), enabled: .src_limiting_enabled, type: (.src_limiting_type | nz) } | compact
                else null end),
              destination_ips: (if (.destination_ips // []) | length > 0
                then [ .destination_ips[] | { destination_ip: (.destination_ip | nz), interface: (.interface | nz) } | compact ]
                else null end)
            } | compact)
          }
        })
        | if (map(.key) | unique | length) != length then error("unifi-adopt: two port forwards share a resource name") else . end
        | from_entries
      '';

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

      # Fixture: the gateway's own record is dropped, peers group by remote ASN,
      # and a peer in the gateway's AS is refused.
      checks.unifi-bgp-render =
        let
          args = {
            name = "t";
            cidr = "10.0.0.0/16";
            asn = 65999;
            routerId = "10.0.0.1";
            peers = [
              {
                hostname = "s2";
                ip = "10.0.1.3";
                asn = 65001;
              }
              {
                hostname = "hub";
                ip = "10.0.1.1";
                asn = 65000;
              }
              {
                hostname = "self";
                ip = "10.0.0.1";
                asn = 65000;
              }
              {
                hostname = "s1";
                ip = "10.0.1.2";
                asn = 65001;
              }
            ];
          };
          rendered = renderBgpConfig args;
          lines = lib.splitString "\n" rendered;
          has = l: builtins.elem l lines;
          ibgp = builtins.tryEval (
            builtins.deepSeq (renderBgpConfig (
              args
              // {
                peers = [
                  {
                    hostname = "x";
                    ip = "10.0.1.9";
                    asn = 65999;
                  }
                ];
              }
            )) null
          );
          ok =
            has "router bgp 65999"
            && has " bgp router-id 10.0.0.1"
            && has " neighbor as65000 remote-as 65000"
            && has " neighbor as65001 remote-as 65001"
            && has " neighbor 10.0.1.1 peer-group as65000"
            && has " neighbor 10.0.1.2 peer-group as65001"
            && has " neighbor 10.0.1.3 peer-group as65001"
            && has "  neighbor as65001 activate"
            && !(lib.hasInfix "10.0.0.1 peer-group" rendered)
            && lib.length (lib.filter (lib.hasSuffix "peer-group") lines) == 2
            && !ibgp.success;
        in
        assert lib.assertMsg ok "unifi-bgp-render:\n${rendered}";
        pkgs.writeText "unifi-bgp-render" rendered;

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
              pfs=$(curl -fksS -H @<(printf 'X-Api-Key: %s\n' "$UNIFI_API_KEY") \
                "$api/proxy/network/api/s/$site/rest/portforward" | jq .data)
              jq -f ${portForwardModel} <<<"$pfs" > ${workdir}/port-forwards.json
              # unifi_bgp is a per-site singleton; its import id is the site name.
              # A port forward imports by its controller _id.
              jq --arg site "$site" --slurpfile pf ${workdir}/port-forwards.json \
                '{ import: ([ { to: .bgp, id: $site } ]
                  + ($pf[0] | to_entries | map({ to: "unifi_port_forward.\(.key)", id: .value.id }))) }' \
                ${meta} > ${workdir}/imports.tf.json
              # The flake reads port-forwards.json only once git tracks it.
              git add ${workdir}/port-forwards.json ${workdir}/imports.tf.json
              echo "unifi-adopt: site $site BGP config $(jq -r '.[0]._id' <<<"$bgp") ($(jq -r '.[0].description' <<<"$bgp"))"
              echo "unifi-adopt: $(jq length <<<"$pfs") port forwards:"
              jq -r '.[] | "  \(.name // "-")\t\(.proto)\twan \(.pfwd_interface // "-"):\(.dst_port // "-")\t-> \(.fwd // "-"):\(.fwd_port // "-")\tenabled=\(.enabled)"' <<<"$pfs"
              echo "unifi-adopt: wrote ${workdir}/port-forwards.json and ${workdir}/imports.tf.json"
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
