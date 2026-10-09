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
#   nix build .#checks.<system>.unifi-nat-render
#   nix build .#checks.<system>.unifi-gateway-policy-render
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
  restapiVersion = "3.0.0";

  # A controller name as a resource name: lowercased, each run of other
  # characters as `_`, the key unifi-adopt derives (portForwardImports).
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

  # `env`'s port-forwards records of one mode ("forward" when unset), keyed by
  # resource name. Two of any mode with the same key, or overlapping WAN ports
  # on overlapping protocols, are refused.
  # ponytail: overlap compares single ports and comma lists, not "a-b" ranges.
  recordsOf =
    mode: env: forwards:
    let
      modeOf =
        r:
        let
          m = r.mode or "forward";
        in
        if
          builtins.elem m [
            "forward"
            "nat"
          ]
        then
          m
        else
          throw "unifi: port forward ${r.name} has mode ${m}, not forward or nat";
      own = builtins.filter (r: r.environment == env) forwards;
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
          lib.nameValuePair (key r.name) r;
    in
    builtins.filter ({ value, ... }: modeOf value == mode) (lib.imap0 check own);

  # The gateway's port forwards: the records with mode "forward". A forward
  # listens on the first WAN, or with `allWans` on every one in `wans` (the
  # controller's destination_ips).
  renderPortForwards =
    {
      env,
      wans,
      forwards,
    }:
    lib.listToAttrs (
      map (
        { name, value }:
        lib.nameValuePair name (
          {
            inherit (value) name protocol forward;
            wan = {
              interface = builtins.head wans;
              port = value.wanPort;
            };
          }
          // lib.optionalAttrs (value.allWans or false) {
            destination_ips = map (interface: {
              destination_ip = "any";
              inherit interface;
            }) wans;
          }
        )
      ) (recordsOf "forward" env forwards)
    );

  # The records with mode "nat" as custom NAT rules (v2 `nat`), one
  # restapi_object each. A port forward to a target off the gateway's own
  # networks masquerades every client; these rules masquerade hairpin clients
  # only, so internet clients reach the target with their own address.
  #   <key>_dnat_wan    public address:wanPort in on the WAN -> forward
  #   <key>_dnat_<lan>  the same in on each LAN (hairpin)
  #   <key>_masq_<lan>  each LAN's clients to forward, out the first LAN
  # The controller requires a DNAT's in_interface and a MASQUERADE's
  # out_interface, both networkconf ids, looked up by `networks` names.
  # Ports are the controller's strings; a /32 filter address is refused, so
  # addresses are bare.
  renderNat =
    {
      env,
      site,
      publicIPv4,
      networks,
      forwards,
    }:
    let
      records = recordsOf "nat" env forwards;
      netKey = n: "unifi_network_${key n}";
      netId = n: "\${data.restapi_object.${netKey n}.id}";
      singlePort =
        r: p:
        if builtins.match "[0-9]+" p != null then
          p
        else
          throw "unifi: nat port forward ${r.name} needs a single port, not ${p}";
      filter =
        extra:
        {
          filter_type = "NONE";
          firewall_group_ids = [ ];
          invert_address = false;
          invert_port = false;
        }
        // extra;
      rule =
        extra:
        {
          enabled = true;
          exclude = false;
          ip_version = "IPV4";
          is_predefined = false;
          logging = false;
          pppoe_use_base_interface = false;
          setting_preference = "manual";
        }
        // extra;
      rulesOf =
        { name, value }:
        let
          r = value;
          dnat = side: iface: {
            name = "${name}_dnat_${side}";
            value = rule {
              type = "DNAT";
              description = "${r.name} dnat ${side}";
              inherit (r) protocol;
              in_interface = netId iface;
              ip_address = r.forward.ip;
              port = singlePort r r.forward.port;
              source_filter = filter { };
              destination_filter = filter {
                filter_type = "ADDRESS_AND_PORT";
                address = publicIPv4;
                port = singlePort r r.wanPort;
              };
            };
          };
          masq = lan: {
            name = "${name}_masq_${key lan}";
            value = rule {
              type = "MASQUERADE";
              description = "${r.name} masquerade ${key lan}";
              inherit (r) protocol;
              out_interface = netId (builtins.head networks.lans);
              source_filter = filter {
                filter_type = "NETWORK_CONF";
                network_conf_id = netId lan;
              };
              destination_filter = filter {
                filter_type = "ADDRESS_AND_PORT";
                address = r.forward.ip;
                port = singlePort r r.forward.port;
              };
            };
          };
        in
        [ (dnat "wan" networks.wan) ]
        ++ map (lan: dnat (key lan) lan) networks.lans
        ++ map masq networks.lans;
      rules = lib.concatMap rulesOf records;
      path = "/v2/api/site/${site}/nat";
    in
    if records == [ ] then
      { }
    else
      assert lib.assertMsg (publicIPv4 != null) "unifi: nat port forwards need dns.publicIPv4";
      assert lib.assertMsg (networks != null) "unifi: nat port forwards need unifi.networks";
      {
        data.restapi_object = lib.genAttrs' (lib.unique ([ networks.wan ] ++ networks.lans)) (
          n:
          lib.nameValuePair (netKey n) {
            path = "/api/s/${site}/rest/networkconf";
            results_key = "data";
            search_key = "name";
            search_value = n;
            results_contains_object = true;
          }
        );
        # rule_index is unique per site and the controller assigns a clashing
        # one when none is sent, so each rule takes its position.
        resource.restapi_object = lib.listToAttrs (
          lib.imap1 (i: { name, value }: {
            inherit name;
            value = {
              inherit path;
              create_path = path;
              # No GET by id: read searches the list for the _id.
              read_path = "${path}/{id}";
              read_search = {
                search_key = "_id";
                search_value = "{id}";
              };
              update_path = "${path}/{id}";
              destroy_path = "${path}/{id}";
              # The controller adds _id, site_id and attr_* fields; drift is
              # judged on the declared ones.
              ignore_server_additions = true;
              data = builtins.toJSON (value // { rule_index = i; });
            };
          }) rules
        );
      };

  # The gateway-policies records as zone-based ALLOW policies, one per source
  # environment: from the named clusters' node addresses (pods masquerade to
  # them) to the destination address and port. Sources in the destination's
  # own environment share its LAN and never cross the gateway, so they render
  # none. Zones are looked up by the controller's name for each environment
  # (`zones`); a cluster with no nodes, or an environment with no zone, is refused.
  renderGatewayPolicies =
    {
      zones,
      nodes,
      policies,
    }:
    let
      zoneKey = e: "zone_${key e}";
      zoneName = e: zones.${e} or (throw "unifi: gateway policies need unifi.zones.${e}");
      zoneId = e: builtins.seq (zoneName e) "\${data.unifi_firewall_zone.${zoneKey e}.id}";
      sourcesOf =
        p:
        lib.concatMap (
          c:
          let
            members = builtins.filter (n: n.clusterName == c) nodes;
          in
          if members == [ ] then
            throw "unifi: gateway policy ${p.name} names cluster ${c}, which has no nodes"
          else
            members
        ) p.sources.clusters;
      rulesOf =
        p:
        lib.mapAttrsToList (src: members: {
          name = key "${p.name}-from-${src}";
          zones = [
            src
            p.destination.environment
          ];
          value = {
            name = "${p.name} from ${src}";
            action = "ALLOW";
            inherit (p) protocol;
            ip_version = "IPV4";
            create_allow_respond = true;
            source = {
              zone_id = zoneId src;
              matching_target = "IP";
              ips = lib.sort (a: b: a < b) (lib.unique (map (n: n.ip) members));
            };
            destination = {
              zone_id = zoneId p.destination.environment;
              matching_target = "IP";
              ips = [ p.destination.ip ];
              inherit (p) port;
              port_matching_type = "SPECIFIC";
            };
          };
        }) (removeAttrs (lib.groupBy (n: n.environment.name) (sourcesOf p)) [ p.destination.environment ]);
      rules = lib.concatMap rulesOf policies;
    in
    if rules == [ ] then
      { }
    else
      {
        data.unifi_firewall_zone = lib.genAttrs' (lib.unique (lib.concatMap (r: r.zones) rules)) (
          e: lib.nameValuePair (zoneKey e) { name = zoneName e; }
        );
        resource.unifi_firewall_policy = lib.listToAttrs (map (r: { inherit (r) name value; }) rules);
      };

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
              zones = mkOption {
                type = types.attrsOf types.str;
                default = { };
                description = "The controller's firewall zone name for each environment's network, for gateway-policies";
              };
              networks = mkOption {
                default = null;
                description = ''
                  The controller's names (networkconf `name`) for the networks a nat
                  port forward's rules name. null = no nat port forwards.
                '';
                type = types.nullOr (
                  types.submodule {
                    options = {
                      wan = mkOption {
                        type = types.str;
                        description = "The network of the first WAN: internet clients come in on it";
                      };
                      lans = mkOption {
                        type = types.nonEmptyListOf types.str;
                        description = "The LANs whose clients reach a nat port forward by the public address (hairpin). The first is the one its targets are routed out of";
                      };
                    };
                  }
                );
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

  # Gateway policies cross environments, and their sources resolve against every
  # cluster's nodes, so both come from all hosts (a guest's through its parent).
  den.policies.env-collect-gateway-policies =
    { environment, ... }:
    lib.optionals (environment.unifi != null) [
      (pipe.from "gateway-policies" [
        (pipe.collectAll ({ host, ... }: true))
      ])
      (pipe.from "k3s-nodes" [
        (pipe.collectAll ({ host, ... }: true))
      ])
    ];

  den.schema.environment.includes = [
    den.policies.env-collect-bgp-peers
    den.policies.env-collect-port-forwards
    den.policies.env-collect-gateway-policies
    den.aspects.unifi-gateway
    den.policies.env-to-unifi-terranix
  ];

  den.aspects.unifi-gateway.unifi-terranix =
    {
      environment,
      bgp-peers ? [ ],
      port-forwards ? [ ],
      gateway-policies ? [ ],
      k3s-nodes ? [ ],
      ...
    }:
    let
      inherit (environment) unifi;
      net = environment.networks.default;
    in
    lib.foldl' lib.recursiveUpdate { } [
      (renderNat {
        env = environment.name;
        inherit (unifi) site networks;
        inherit (environment.dns) publicIPv4;
        forwards = port-forwards;
      })
      (renderGatewayPolicies {
        inherit (unifi) zones;
        nodes = k3s-nodes;
        policies = gateway-policies;
      })
      {
        terraform = {
          required_providers = {
            unifi = {
              source = "ubiquiti-community/unifi";
              version = "0.56.1";
            };
            # The gateway's custom NAT rules (v2 nat), which the unifi provider has no resource for.
            restapi = {
              source = "Mastercard/restapi";
              version = restapiVersion;
            };
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

        variable.unifi_api_key = {
          type = "string";
          sensitive = true;
          description = "The UniFi API key for the restapi provider (TF_VAR_unifi_api_key)";
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

        # The v2 API answers a write with the bare object, a list with a bare array.
        provider.restapi = {
          uri = "https://${environment.networks.default.gatewayIp}/proxy/network";
          insecure = true;
          headers."X-API-KEY" = "\${var.unifi_api_key}";
          id_attribute = "_id";
          create_returns_object = true;
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
      }
    ];

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
        [[ -s $identity ]] || { echo "no YubiKey identity found; plug in the YubiKey" >&2; exit 1; }
        UNIFI_API_KEY=$(age -d -i "$identity" .secrets/env/${unifiEnv}/unifi-api-key.age)
        TF_VAR_state_passphrase=$(age -d -i "$identity" .secrets/env/${unifiEnv}/unifi-state-passphrase.age)
        TF_VAR_unifi_api_key=$UNIFI_API_KEY
        export UNIFI_API_KEY TF_VAR_unifi_api_key TF_VAR_state_passphrase
      '';

      # Not in nixpkgs. The registry.terraform.io address is the one opentofu's
      # withPlugins rewrites to registry.opentofu.org.
      restapi = pkgs.terraform-providers.mkProvider {
        owner = "Mastercard";
        repo = "terraform-provider-restapi";
        rev = "v${restapiVersion}";
        hash = "sha256-XdOyOIrE090+QzeGQg7sn5GdaH9Jv47HdcuIH1/kDVM=";
        vendorHash = "sha256-O9j62HQEw1d+OEK/9sJpC6FPsVu8cDD0vxwVpvHHCvk=";
        spdx = "Apache-2.0";
        homepage = "https://registry.terraform.io/providers/Mastercard/restapi";
        provider-source-address = "registry.terraform.io/mastercard/restapi";
      };

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
        terraformWrapper.package = pkgs.opentofu.withPlugins (p: [
          p.ubiquiti-community_unifi
          restapi
        ]);
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
            (
              host
              // {
                name = "ssh-nat";
                mode = "nat";
                wanPort = "2222";
              }
            )
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

      # Fixture: a nat record renders as the WAN DNAT, a hairpin DNAT per LAN and
      # a masquerade per LAN out of the first, with these exact payloads; a
      # forward record and another environment's nat record render no rule; a
      # port list, an unknown mode, a forward on the same port and a missing
      # networks are refused.
      checks.unifi-nat-render =
        let
          nat = {
            environment = "t";
            name = "c1-https-ingress";
            mode = "nat";
            protocol = "tcp_udp";
            wanPort = "443";
            forward = {
              ip = "10.1.0.1";
              port = "443";
            };
          };
          args = {
            env = "t";
            site = "s";
            publicIPv4 = "192.0.2.1";
            networks = {
              wan = "Internet 1";
              lans = [
                "Default"
                "dev"
              ];
            };
            forwards = [
              nat
              (
                removeAttrs nat [ "mode" ]
                // {
                  name = "ssh";
                  wanPort = "22";
                }
              )
              (
                nat
                // {
                  environment = "u";
                  name = "c2";
                }
              )
            ];
          };
          rendered = renderNat args;
          rules = rendered.resource.restapi_object;
          payload = n: builtins.fromJSON rules.${n}.data;
          refused = a: !(builtins.tryEval (builtins.deepSeq (renderNat (args // a)) null)).success;
          filter =
            extra:
            {
              filter_type = "NONE";
              firewall_group_ids = [ ];
              invert_address = false;
              invert_port = false;
            }
            // extra;
          common = {
            enabled = true;
            exclude = false;
            ip_version = "IPV4";
            is_predefined = false;
            logging = false;
            pppoe_use_base_interface = false;
            setting_preference = "manual";
            protocol = "tcp_udp";
          };
          dnat =
            side: iface: index:
            common
            // {
              type = "DNAT";
              description = "c1-https-ingress dnat ${side}";
              in_interface = "\${data.restapi_object.unifi_network_${iface}.id}";
              ip_address = "10.1.0.1";
              port = "443";
              rule_index = index;
              source_filter = filter { };
              destination_filter = filter {
                filter_type = "ADDRESS_AND_PORT";
                address = "192.0.2.1";
                port = "443";
              };
            };
          masq =
            lan: index:
            common
            // {
              type = "MASQUERADE";
              description = "c1-https-ingress masquerade ${lan}";
              out_interface = "\${data.restapi_object.unifi_network_default.id}";
              rule_index = index;
              source_filter = filter {
                filter_type = "NETWORK_CONF";
                network_conf_id = "\${data.restapi_object.unifi_network_${lan}.id}";
              };
              destination_filter = filter {
                filter_type = "ADDRESS_AND_PORT";
                address = "10.1.0.1";
                port = "443";
              };
            };
          ok =
            builtins.attrNames rules == [
              "c1_https_ingress_dnat_default"
              "c1_https_ingress_dnat_dev"
              "c1_https_ingress_dnat_wan"
              "c1_https_ingress_masq_default"
              "c1_https_ingress_masq_dev"
            ]
            && payload "c1_https_ingress_dnat_wan" == dnat "wan" "internet_1" 1
            && payload "c1_https_ingress_dnat_default" == dnat "default" "default" 2
            && payload "c1_https_ingress_dnat_dev" == dnat "dev" "dev" 3
            && payload "c1_https_ingress_masq_default" == masq "default" 4
            && payload "c1_https_ingress_masq_dev" == masq "dev" 5
            &&
              rules.c1_https_ingress_dnat_wan.read_search == {
                search_key = "_id";
                search_value = "{id}";
              }
            && rules.c1_https_ingress_dnat_wan.destroy_path == "/v2/api/site/s/nat/{id}"
            &&
              builtins.attrNames rendered.data.restapi_object == [
                "unifi_network_default"
                "unifi_network_dev"
                "unifi_network_internet_1"
              ]
            && rendered.data.restapi_object.unifi_network_dev.search_value == "dev"
            && renderNat (args // { forwards = [ (removeAttrs nat [ "mode" ]) ]; }) == { }
            && refused { forwards = [ (nat // { wanPort = "443,8443"; }) ]; }
            && refused { forwards = [ (nat // { mode = "dnat"; }) ]; }
            && refused {
              forwards = [
                nat
                (removeAttrs nat [ "mode" ] // { name = "c1-forward"; })
              ];
            }
            && refused { networks = null; };
        in
        assert lib.assertMsg ok "unifi-nat-render:\n${builtins.toJSON rendered}";
        pkgs.writeText "unifi-nat-render" (builtins.toJSON rendered);

      # Fixture: a policy renders one ALLOW per source environment from its
      # cluster's node addresses, a same-environment source renders none, and
      # an unknown cluster or a missing zone is refused.
      checks.unifi-gateway-policy-render =
        let
          node = clusterName: env: ip: {
            inherit clusterName ip;
            environment.name = env;
          };
          args = {
            zones = {
              p = "Internal";
              d = "Dev";
            };
            nodes = [
              (node "c1" "p" "10.1.0.3")
              (node "c1" "p" "10.1.0.2")
              (node "c2" "d" "10.2.0.5")
            ];
            policies = [
              {
                name = "svc-to-h";
                protocol = "tcp";
                port = "8081";
                destination = {
                  environment = "d";
                  ip = "10.2.0.9";
                };
                sources.clusters = [
                  "c1"
                  "c2"
                ];
              }
            ];
          };
          rendered = renderGatewayPolicies args;
          policy = rendered.resource.unifi_firewall_policy;
          refused =
            a: !(builtins.tryEval (builtins.deepSeq (renderGatewayPolicies (args // a)) null)).success;
          ok =
            builtins.attrNames policy == [ "svc_to_h_from_p" ]
            &&
              policy.svc_to_h_from_p.source == {
                zone_id = "\${data.unifi_firewall_zone.zone_p.id}";
                matching_target = "IP";
                ips = [
                  "10.1.0.2"
                  "10.1.0.3"
                ];
              }
            &&
              policy.svc_to_h_from_p.destination == {
                zone_id = "\${data.unifi_firewall_zone.zone_d.id}";
                matching_target = "IP";
                ips = [ "10.2.0.9" ];
                port = "8081";
                port_matching_type = "SPECIFIC";
              }
            && rendered.data.unifi_firewall_zone.zone_d.name == "Dev"
            && refused { policies = map (p: p // { sources.clusters = [ "c3" ]; }) args.policies; }
            && refused { zones.d = "Dev"; };
        in
        assert lib.assertMsg ok "unifi-gateway-policy-render:\n${builtins.toJSON rendered}";
        pkgs.writeText "unifi-gateway-policy-render" (builtins.toJSON rendered);

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
