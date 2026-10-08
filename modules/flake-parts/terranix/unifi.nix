# Terranix: the UniFi gateway as code, applied with OpenTofu (infra/unifi/README.md).
#
# A separate workspace and state from DNS (./terranix.nix). Every environment
# with `unifi` set instantiates its `unifi-terranix` class into
# flake.unifiTerranixModules.<env>. The gateway is one device and one UniFi
# site for prod and dev alike, so exactly one environment may set `unifi`.
#
#   nix build .#unifi.config   — config.tf.json
#   nix build .#checks.<system>.unifi-bgp-render
#   nix build .#checks.<system>.unifi-port-forward-render
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
  unifiTerranixModules = config.flake.unifiTerranixModules.${unifiEnv};

  # The gateway's port forwards, keyed by the resource name unifi-adopt derives
  # from a forward's controller name (portForwardImports). Only `env`'s
  # records are rendered. A forward listens on the first WAN, or with `allWans`
  # on every one in `wans` (the controller's destination_ips).
  # ponytail: overlap compares single ports and comma lists, not "a-b" ranges.
  renderPortForwards =
    {
      env,
      wans,
      forwards,
    }:
    let
      own = builtins.filter (r: r.environment == env) forwards;
      key =
        n:
        let
          k = lib.removePrefix "_" (
            lib.removeSuffix "_" (
              lib.concatMapStrings (x: if builtins.isList x then "_" else x) (
                builtins.split "[^a-z0-9]+" (lib.toLower n)
              )
            )
          );
        in
        if builtins.match "[0-9].*" k != null then "pf_" + k else k;
      ports = r: lib.splitString "," r.wanPort;
      overlaps =
        a: b:
        (a.protocol == b.protocol || a.protocol == "tcp_udp" || b.protocol == "tcp_udp")
        && lib.intersectLists (ports a) (ports b) != [ ];
      check =
        i: r:
        let
          earlier = lib.take i own;
          clash = lib.findFirst (o: key o.name == key r.name) null earlier;
          portClash = lib.findFirst (o: overlaps o r) null earlier;
        in
        if clash != null then
          throw "unifi: port forwards ${clash.name} and ${r.name} share the resource name ${key r.name}"
        else if portClash != null then
          throw "unifi: port forwards ${portClash.name} and ${r.name} both take ${r.protocol} wan:${r.wanPort}"
        else
          lib.nameValuePair (key r.name) (
            {
              inherit (r) name protocol forward;
              wan = {
                interface = builtins.head wans;
                port = r.wanPort;
              };
            }
            // lib.optionalAttrs (r.allWans or false) {
              destination_ips = map (interface: {
                destination_ip = "any";
                inherit interface;
              }) wans;
            }
          );
    in
    lib.listToAttrs (lib.imap0 check own);

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
              wans = mkOption {
                type = types.nonEmptyListOf types.str;
                default = [ "wan" ];
                description = "The gateway's WAN interfaces: a port forward's wan side is the first, and an allWans forward listens on each";
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

  # Hosts (headscale, public ssh) and clusters (the gateway's https ingress) emit
  # port-forwards; a collectAll predicate matches one entity kind, so each takes its own.
  den.policies.env-collect-port-forwards =
    { environment, ... }:
    [
      (pipe.from "port-forwards" [
        (pipe.collectAll ({ host, ... }: host.environment == environment.name))
      ])
      (pipe.from "port-forwards" [
        (pipe.collectAll ({ cluster, ... }: cluster.environment == environment.name))
      ])
    ];

  den.schema.environment.includes = [
    den.policies.env-collect-bgp-peers
    den.policies.env-collect-port-forwards
    den.aspects.unifi-gateway
    den.policies.env-to-unifi-terranix
  ];

  den.aspects.unifi-gateway.unifi-terranix =
    {
      environment,
      bgp-peers ? [ ],
      port-forwards ? [ ],
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

      resource.unifi_port_forward = renderPortForwards {
        env = environment.name;
        inherit (unifi) wans;
        forwards = port-forwards;
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

      # Each live forward (rest/portforward) as an import block, its resource name
      # derived from its controller name as renderPortForwards keys it.
      portForwardImports = pkgs.writeText "unifi-port-forward-imports.jq" ''
        def nz: if . == null or . == "" then null else . end;
        def key: ((.name | nz) // ._id) | ascii_downcase | gsub("[^a-z0-9]+"; "_") | gsub("^_|_$"; "")
          | if test("^[0-9]") then "pf_" + . else . end;
        map({ to: "unifi_port_forward.\(key)", id: ._id })
        | if (map(.to) | unique | length) != length then error("unifi-adopt: two port forwards share a resource name") else . end
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

      # Fixture: host and cluster records render under their adopt-derived keys,
      # another environment's record is dropped, and a shared resource name or
      # an overlapping WAN port is refused.
      checks.unifi-port-forward-render =
        let
          host = {
            environment = "t";
            name = "ssh-to-h1";
            protocol = "tcp";
            wanPort = "22";
            forward = {
              ip = "10.0.0.5";
              port = "22";
            };
          };
          cluster = {
            environment = "t";
            name = "c1-https-ingress";
            protocol = "tcp_udp";
            wanPort = "443";
            forward = {
              ip = "10.1.0.1";
              port = "443";
            };
            allWans = true;
          };
          other = cluster // {
            environment = "u";
            name = "c2-https-ingress";
          };
          render =
            forwards:
            renderPortForwards {
              env = "t";
              wans = [
                "wan"
                "wan2"
              ];
              inherit forwards;
            };
          rendered = render [
            host
            cluster
            other
          ];
          refused = forwards: !(builtins.tryEval (builtins.deepSeq (render forwards) null)).success;
          ok =
            builtins.attrNames rendered == [
              "c1_https_ingress"
              "ssh_to_h1"
            ]
            &&
              rendered.ssh_to_h1 == {
                name = "ssh-to-h1";
                protocol = "tcp";
                wan = {
                  interface = "wan";
                  port = "22";
                };
                forward = {
                  ip = "10.0.0.5";
                  port = "22";
                };
              }
            &&
              map (d: d.interface) rendered.c1_https_ingress.destination_ips == [
                "wan"
                "wan2"
              ]
            && rendered.c1_https_ingress.forward.ip == "10.1.0.1"
            && refused [
              host
              (host // { wanPort = "2222"; })
            ]
            && refused [
              cluster
              (host // { wanPort = "8443,443"; })
            ]
            && !refused [
              host
              (
                host
                // {
                  name = "dns";
                  protocol = "udp";
                }
              )
            ];
        in
        assert lib.assertMsg ok "unifi-port-forward-render:\n${builtins.toJSON rendered}";
        pkgs.writeText "unifi-port-forward-render" (builtins.toJSON rendered);

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
              # unifi_bgp is a per-site singleton; its import id is the site name.
              # A port forward imports by its controller _id. Its config is the
              # declared one (port-forwards); a live forward with none fails the plan.
              jq --arg site "$site" --argjson pf "$(jq -f ${portForwardImports} <<<"$pfs")" \
                '{ import: ([ { to: .bgp, id: $site } ] + $pf) }' \
                ${meta} > ${workdir}/imports.tf.json
              # The flake reads imports.tf.json only once git tracks it.
              git add ${workdir}/imports.tf.json
              echo "unifi-adopt: site $site BGP config $(jq -r '.[0]._id' <<<"$bgp") ($(jq -r '.[0].description' <<<"$bgp"))"
              echo "unifi-adopt: $(jq length <<<"$pfs") port forwards:"
              jq -r '.[] | "  \(.name // "-")\t\(.proto)\twan \(.pfwd_interface // "-"):\(.dst_port // "-")\t-> \(.fwd // "-"):\(.fwd_port // "-")\tenabled=\(.enabled)"' <<<"$pfs"
              echo "unifi-adopt: wrote ${workdir}/imports.tf.json"
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
