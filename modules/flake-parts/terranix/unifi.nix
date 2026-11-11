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
#   nix build .#checks.<system>.unifi-network-policy-render
#   nix build .#checks.<system>.unifi-dhcp-dns-render
#   nix build .#checks.<system>.unifi-dhcp-option-render
#   nix build .#checks.<system>.unifi-reservation-render
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
  resolvers = import ../../den/aspects/core/network/_resolvers.nix { inherit lib; };
  plan = import ../../den/schema/_address-plan.nix { inherit lib; };

  # ponytail: one environment owns the gateway; key configs by env if a second controller appears.
  unifiEnv = "prod";
  workdir = "infra/unifi";
  unifiTerranixModules = config.flake.unifiTerranixModules.${unifiEnv};
  # The fleet's den config, for perSystem (whose `config` is the system's).
  fleet = config.den;

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

  # The gateway runs the zone-based firewall: a policy names its source and
  # destination zones by id, looked up from their controller names.
  zoneKey = z: "unifi_zone_${key z}";
  zoneId = z: "\${data.unifi_firewall_zone.${zoneKey z}.id}";
  zonesData = names: {
    data.unifi_firewall_zone = lib.genAttrs' names (z: lib.nameValuePair (zoneKey z) { name = z; });
  };

  # One unifi_firewall_policy allowing `protocol` to `ip`:`port` across a zone
  # pair, and its _meta entry, which unifi-adopt matches a live policy against by
  # name and zone pair.
  zonePolicy =
    {
      resource,
      name,
      protocol,
      from,
      to,
      source,
      ip,
      port,
    }:
    {
      resource.unifi_firewall_policy.${resource} = {
        inherit name protocol;
        action = "ALLOW";
        enabled = true;
        ip_version = "IPV4";
        source = {
          zone_id = zoneId from;
        }
        // source;
        destination = {
          zone_id = zoneId to;
          matching_target = "IP";
          ips = [ ip ];
          port_matching_type = "SPECIFIC";
          inherit port;
        };
      };
      _meta.policies.${resource} = {
        inherit name;
        source = from;
        destination = to;
      };
    };

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
  # A custom NAT rule, unlike a port forward, gets no policy from the
  # controller, and the zone firewall blocks External traffic no policy admits,
  # so each record also takes unifi_firewall_policy.<key>_allow: any External
  # source to forward. Its destination zone is External, not Internal: a nat
  # forward targets a BGP-announced service address, outside every LAN, and the
  # zone firewall puts an address in no network in External (measured on the
  # 6.0.17 firmware: the ingress's DNATed SYNs counted on External -> External
  # Block All).
  # shortcut: assumes every nat forward targets an address outside the LANs; key
  #   the zone off the target if one ever forwards to a LAN host.
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
      lib.foldl' lib.recursiveUpdate
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
          # Read by unifi-adopt, which imports each rule by its description: the
          # firmware's zone migration re-created every rule under a new _id.
          _meta.nat = lib.listToAttrs (
            map ({ name, value }: lib.nameValuePair name { inherit (value) description; }) rules
          );
        }
        (
          [ (zonesData [ "External" ]) ]
          ++ map (
            { name, value }:
            zonePolicy {
              resource = "${name}_allow";
              name = "${value.name} allow";
              inherit (value) protocol;
              from = "External";
              to = "External";
              source = {
                matching_target = "ANY";
                port_matching_type = "ANY";
              };
              ip = value.forward.ip;
              port = singlePort value value.forward.port;
            }
          ) records
        );

  # The gateway-policies records as zone policies, Internal -> Internal (both
  # environments' LANs are in the Internal zone), one per source environment:
  # from an address group of the named clusters' node addresses (pods masquerade
  # to them) to the destination address and port. Sources in the destination's
  # own environment share its LAN and never cross the gateway, so they render
  # none. A cluster with no nodes is refused. The legacy LAN_IN rules these
  # replaced are dropped from state, never destroyed: the firmware's zone
  # migration already removed them from the controller.
  renderGatewayPolicies =
    { nodes, policies }:
    let
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
          group = {
            name = "${p.name} from ${src}";
            type = "address-group";
            members = lib.sort (a: b: a < b) (lib.unique (map (n: n.ip) members));
          };
          inherit (p) protocol port;
          inherit (p.destination) ip;
        }) (removeAttrs (lib.groupBy (n: n.environment.name) (sourcesOf p)) [ p.destination.environment ]);
      rules = lib.concatMap rulesOf policies;
    in
    if rules == [ ] then
      { }
    else
      lib.foldl' lib.recursiveUpdate
        {
          resource.unifi_firewall_group = lib.listToAttrs (map (r: lib.nameValuePair r.name r.group) rules);
          removed = map (r: {
            from = "unifi_firewall_rule.${r.name}";
            lifecycle.destroy = false;
          }) rules;
        }
        (
          [ (zonesData [ "Internal" ]) ]
          ++ map (
            r:
            zonePolicy {
              resource = r.name;
              inherit (r.group) name;
              inherit (r) protocol ip port;
              from = "Internal";
              to = "Internal";
              source = {
                matching_target = "IP";
                ip_group_id = "\${unifi_firewall_group.${r.name}.id}";
                port_matching_type = "ANY";
              };
            }
          ) rules
        );

  # The unifi.networkPolicies records as Internal -> Internal allows from one
  # network to another (both environments' LANs are in the Internal zone),
  # networks looked up by their controller names.
  renderNetworkPolicies =
    { site, policies }:
    let
      netKey = n: "unifi_network_${key n}";
      netId = n: "\${data.restapi_object.${netKey n}.id}";
      endpoint = n: {
        zone_id = zoneId "Internal";
        matching_target = "NETWORK";
        network_ids = [ (netId n) ];
        port_matching_type = "ANY";
      };
      policy =
        p:
        let
          resource = key p.name;
        in
        {
          resource.unifi_firewall_policy.${resource} = {
            inherit (p) name protocol;
            action = "ALLOW";
            enabled = true;
            ip_version = "IPV4";
            source = endpoint p.from;
            destination = endpoint p.to;
          };
          _meta.policies.${resource} = {
            inherit (p) name;
            source = "Internal";
            destination = "Internal";
          };
        };
    in
    if policies == [ ] then
      { }
    else
      lib.foldl' lib.recursiveUpdate {
        data.restapi_object =
          lib.genAttrs'
            (lib.unique (
              lib.concatMap (p: [
                p.from
                p.to
              ]) policies
            ))
            (
              n:
              lib.nameValuePair (netKey n) {
                path = "/api/s/${site}/rest/networkconf";
                results_key = "data";
                search_key = "name";
                search_value = n;
                results_contains_object = true;
              }
            );
      } ([ (zonesData [ "Internal" ]) ] ++ map policy policies);

  # Each environment's controller network (networks.default.unifiNetwork) hands
  # out resolversFor dns.dhcpResolvers as its DHCP DNS, and as its DHCPv6 DNS the
  # IPv6 (dns6, ULA) addresses of those instances in the same environment, the
  # only LAN that address is on-link for; never its own (docs/dns-resolver.md
  # §2.4(a)). An environment whose dns.dhcpResolvers is empty renders none.
  # Beside the DNS fields, a network with a dhcpRange (the LAN after its static
  # block, networks.default.staticCidr) renders it as dhcpd_start/dhcpd_stop.
  # The PUT body is the whole live network (the data source, read at plan time)
  # with these fields laid over it, so it is safe whether or not the controller
  # merges a partial PUT (§7 Q4). With that full body, ignore_server_additions
  # stays false: restapi's Read then refreshes the state from the live object, so
  # the plan shows exactly the declared fields that differ from it.
  #   create: PUT to the live _id (the body carries it), never a POST
  #   destroy: a GET, so dropping the resource from state can never delete a LAN
  # A precondition refuses the plan unless the live object carries the DHCP and
  # DHCPv6 DNS switches, so a wrong field name is never invented on the controller.
  # Output unifi_network_dns shows each declared field's live and declared value.
  renderNetworkDns =
    {
      site,
      environments,
      dns-resolvers,
    }:
    let
      path = "/api/s/${site}/rest/networkconf";
      netKey = n: "unifi_network_${key n}";
      live = n: "jsondecode(data.restapi_object.${netKey n}.api_response)";
      required = [
        "dhcpd_dns_enabled"
        "dhcpdv6_dns_auto"
        "dhcpd_start"
        "dhcpd_stop"
      ];
      slots =
        prefix: values:
        lib.genAttrs' (lib.range 1 4) (
          i:
          lib.nameValuePair "${prefix}_${toString i}" (
            lib.elemAt (
              values
              ++ [
                ""
                ""
                ""
                ""
              ]
            ) (i - 1)
          )
        );
      fieldsOf =
        e:
        let
          servers = resolvers.resolversFor { list = "dhcpResolvers"; } e dns-resolvers;
          range = e.networks.default.dhcpRange or null;
          # servers above has already refused an unknown name.
          servers6 = lib.concatMap (
            n:
            let
              r = lib.findFirst (r: r.name == n) { } dns-resolvers;
            in
            lib.optional (r.environment or null == e.name && r.dns6 or null != null) r.dns6
          ) e.dns.dhcpResolvers;
        in
        if servers == null then
          null
        else if lib.length servers > 4 then
          throw "unifi: environment ${e.name} has ${toString (lib.length servers)} DHCP DNS servers; the controller takes 4"
        else
          {
            dhcpd_dns_enabled = true;
            dhcpdv6_dns_auto = false;
          }
          // slots "dhcpd_dns" servers
          // slots "dhcpdv6_dns" servers6
          // lib.optionalAttrs (range != null) {
            dhcpd_start = range.start;
            dhcpd_stop = range.stop;
          };
      nets = lib.concatMap (
        e:
        let
          n = e.networks.default.unifiNetwork or null;
          fields = if n == null then null else fieldsOf e;
        in
        lib.optional (fields != null) { inherit n fields; }
      ) environments;
      byId = "${path}/{id}";
    in
    if nets == [ ] then
      { }
    else
      {
        data.restapi_object = lib.listToAttrs (
          map (
            { n, ... }:
            lib.nameValuePair (netKey n) {
              inherit path;
              results_key = "data";
              search_key = "name";
              search_value = n;
              results_contains_object = true;
            }
          ) nets
        );
        locals = lib.listToAttrs (map ({ n, fields }: lib.nameValuePair "${netKey n}_dns" fields) nets);
        resource.restapi_object = lib.listToAttrs (
          map (
            { n, ... }:
            lib.nameValuePair "network_${key n}" {
              inherit path;
              create_method = "PUT";
              create_path = byId;
              # A GET by id answers { meta, data = [ … ] }; read searches the list.
              read_path = byId;
              read_search = {
                results_key = "data";
                search_key = "_id";
                search_value = "{id}";
              };
              update_path = byId;
              destroy_method = "GET";
              destroy_path = byId;
              data = "\${jsonencode(merge(${live n}, local.${netKey n}_dns))}";
              lifecycle = {
                prevent_destroy = true;
                precondition = [
                  {
                    condition = "\${alltrue([for k in ${builtins.toJSON required} : contains(keys(${live n}), k)])}";
                    error_message = "unifi: network ${n} lacks one of ${lib.concatStringsSep ", " required}; read unifi-adopt's field list (docs/dns-resolver.md §7 Q4)";
                  }
                ];
              };
            }
          ) nets
        );
        output.unifi_network_dns.value = lib.listToAttrs (
          map (
            { n, ... }:
            lib.nameValuePair n "\${{ for k, v in local.${netKey n}_dns : k => { live = try(${live n}[k], null), declared = v } }}"
          ) nets
        );
        # Read by unifi-adopt, which imports each network by the one live network with its name.
        _meta.networks = lib.listToAttrs (map ({ n, ... }: lib.nameValuePair "network_${key n}" n) nets);
      };

  # The DHCP reservations (docs/address-plan.md §2.3): every den host with an
  # IPv4 on an environment's controller network (networks.default with a
  # unifiNetwork), as { name; ip; mac; network; }, its MAC the one declared on the
  # interface holding that address, lowercased. Hosts outside den (the NAS) and
  # addresses no host holds (the API VIP) are never in it. A host with no MAC
  # there, and two hosts on one MAC, are refused.
  reservationsOf =
    environments: hosts:
    let
      rows = lib.concatMap (
        h:
        let
          net = (environments.${h.environment} or { }).networks.default or null;
          holding = lib.concatMap (
            i:
            map (ip: { inherit ip i; }) (
              lib.filter (plan.ipv4InCidr net.cidr) (map (a: lib.head (lib.splitString "/" a)) (i.ipv4 or [ ]))
            )
          ) (lib.attrValues (h.networking.interfaces or { }));
          held = lib.head holding;
        in
        if net == null || net.unifiNetwork or null == null || holding == [ ] then
          [ ]
        else if held.i.mac or null == null then
          throw "unifi: host ${h.name} holds ${held.ip} on ${net.unifiNetwork} but declares no MAC on that interface (networking.interfaces.<n>.mac); its reservation needs one"
        else
          [
            {
              inherit (h) name;
              inherit (held) ip;
              mac = lib.toLower held.i.mac;
              network = net.unifiNetwork;
            }
          ]
      ) hosts;
      shared = lib.filterAttrs (_: rs: lib.length rs > 1) (lib.groupBy (r: r.mac) rows);
    in
    if shared != { } then
      throw "unifi: hosts ${
        lib.concatMapStringsSep ", " (rs: lib.concatMapStringsSep "/" (r: r.name) rs) (
          lib.attrValues shared
        )
      } share a MAC"
    else
      rows;

  # Each reservation as its live client record (rest/user, go-unifi's Client)
  # with fixed_ip, name, use_fixedip and network_id laid over it: the networks'
  # full-body pattern (renderNetworkDns), so ignore_server_additions stays false
  # and the plan shows exactly the declared fields that differ.
  #   lookup: the one live client with the MAC (the controller stores it lowercase)
  #   create: PUT to the live _id, never a POST
  #   destroy: a PUT of the live record with use_fixedip false; the client is
  #     never forgotten
  # shortcut: a MAC the controller has never seen fails the plan at its lookup;
  #   connect the host once (or POST rest/user by hand) before applying.
  # shortcut: destroy_data is the record as of the last apply, so a field changed
  #   on the controller since then is rewritten on removal.
  # Output unifi_reservations shows each declared field's live and declared value.
  renderReservations =
    { site, reservations }:
    let
      path = "/api/s/${site}/rest/user";
      byId = "${path}/{id}";
      netKey = n: "unifi_network_${key n}";
      res = r: "client_${key r.name}";
      clientKey = r: "unifi_client_${key r.name}";
      live = r: "jsondecode(data.restapi_object.${clientKey r}.api_response)";
    in
    if reservations == [ ] then
      { }
    else
      {
        data.restapi_object =
          lib.listToAttrs (
            map (
              r:
              lib.nameValuePair (clientKey r) {
                inherit path;
                results_key = "data";
                search_key = "mac";
                search_value = r.mac;
                results_contains_object = true;
              }
            ) reservations
          )
          // lib.genAttrs' (lib.unique (map (r: r.network) reservations)) (
            n:
            lib.nameValuePair (netKey n) {
              path = "/api/s/${site}/rest/networkconf";
              results_key = "data";
              search_key = "name";
              search_value = n;
              results_contains_object = true;
            }
          );
        locals = lib.listToAttrs (
          map (
            r:
            lib.nameValuePair "${clientKey r}_fixed" {
              inherit (r) name;
              fixed_ip = r.ip;
              use_fixedip = true;
              network_id = "\${data.restapi_object.${netKey r.network}.id}";
            }
          ) reservations
        );
        resource.restapi_object = lib.listToAttrs (
          map (
            r:
            lib.nameValuePair (res r) {
              inherit path;
              create_method = "PUT";
              create_path = byId;
              read_path = byId;
              read_search = {
                results_key = "data";
                search_key = "_id";
                search_value = "{id}";
              };
              update_path = byId;
              destroy_method = "PUT";
              destroy_path = byId;
              data = "\${jsonencode(merge(${live r}, local.${clientKey r}_fixed))}";
              destroy_data = "\${jsonencode(merge(${live r}, { use_fixedip = false }))}";
            }
          ) reservations
        );
        output.unifi_reservations.value = lib.listToAttrs (
          map (
            r:
            lib.nameValuePair r.name "\${{ for k, v in local.${clientKey r}_fixed : k => { live = try(${live r}[k], null), declared = v } }}"
          ) reservations
        );
        # Read by unifi-adopt, which imports each reservation by the one live client with its MAC.
        _meta.clients = lib.listToAttrs (map (r: lib.nameValuePair (res r) r.mac) reservations);
      };

  # A custom DHCP option definition (rest/dhcpoption, go-unifi's DHCPOption),
  # which a network then sets a value for. The v1 API answers a POST with
  # { meta, data = [ object ] }, so the id is data/0/_id, and with that id path
  # read GETs by id (read_search would look the id path up inside each listed
  # object). Destroy DELETEs: a definition is safe to remove. width is omitted;
  # the controller reads it for integer options only, and code is a number, as
  # the UI writes it. A network sets the option's value in its field
  # dhcpd_user_option_<this _id>. The provider never drops a definition deleted
  # on the controller from state; unifi-adopt does, when it imports the live one.
  renderDhcpOption =
    {
      site,
      code,
      name,
      type,
    }:
    let
      path = "/api/s/${site}/rest/dhcpoption";
      res = "dhcp_option_${key name}";
    in
    {
      resource.restapi_object.${res} = {
        inherit path;
        id_attribute = "data/0/_id";
        read_path = "${path}/{id}";
        update_path = "${path}/{id}";
        destroy_path = "${path}/{id}";
        # The controller adds _id, site_id and attr_* fields.
        ignore_server_additions = true;
        data = builtins.toJSON {
          inherit code name type;
          signed = false;
        };
      };
      # Read by unifi-adopt, which imports the one live definition with this code.
      _meta.dhcpOptions.${res} = code;
    };

  # RFC 3442 classless static routes (DHCP option 121) as colon-separated
  # uppercase hex octets, the form the controller stores: per route, its prefix
  # width, the destination's significant octets (ceil(width / 8)), then the
  # router's four. A destination with host bits set
  # is refused. A client honouring 121 ignores option 3, so a list for a
  # network's clients carries the default route too.
  classlessRoutes =
    routes:
    let
      octets = ip: map lib.toInt (lib.splitString "." ip);
      hex = x: lib.fixedWidthString 2 "0" (lib.toHexString x);
      encode =
        { destination, router }:
        let
          parts = lib.splitString "/" destination;
          addr = octets (lib.head parts);
          width = lib.toInt (lib.last parts);
          # Each octet's step at its share of the width (8 bits: 1, 0 bits: 256).
          step =
            i:
            lib.elemAt [
              256
              128
              64
              32
              16
              8
              4
              2
              1
            ] (lib.min 8 (lib.max 0 (width - 8 * i)));
          masked = lib.imap0 (i: o: o - lib.mod o (step i)) addr;
        in
        if masked != addr then
          throw "unifi: classless route ${destination} has host bits set"
        else
          [ width ] ++ lib.take ((width + 7) / 8) addr ++ octets router;
    in
    lib.concatMapStringsSep ":" hex (lib.concatMap encode routes);

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
              networkPolicies = mkOption {
                default = [ ];
                description = ''
                  Zone policies allowing one network's clients to reach another,
                  by the controller's network names (networkconf `name`), both in
                  the Internal zone.
                '';
                type = types.listOf (
                  types.submodule {
                    options = {
                      name = mkOption {
                        type = types.str;
                        description = "The policy's controller name; unifi-adopt matches a live policy by it";
                      };
                      from = mkOption {
                        type = types.str;
                        description = "The source network";
                      };
                      to = mkOption {
                        type = types.str;
                        description = "The destination network";
                      };
                      protocol = mkOption {
                        type = types.enum [
                          "all"
                          "tcp"
                          "udp"
                          "tcp_udp"
                        ];
                        default = "all";
                        description = "The protocols allowed";
                      };
                    };
                  }
                );
              };
              wans = mkOption {
                type = types.nonEmptyListOf types.str;
                default = [ "wan" ];
                description = "The gateway's WAN interfaces: a port forward's wan side is the first, and an allWans forward listens on each";
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

  # The resolver instances, for the networks' DHCP DNS (renderNetworkDns). Every
  # environment's network is written from the one workspace, so all records come;
  # resolversFor picks by name. A collectAll predicate matches one entity kind.
  den.policies.env-collect-dns-resolvers =
    { environment, ... }:
    lib.optionals (environment.unifi != null) [
      (pipe.from "dns-resolvers" [ (pipe.collectAll ({ host, ... }: true)) ])
      (pipe.from "dns-resolvers" [ (pipe.collectAll ({ cluster, ... }: true)) ])
    ];

  den.schema.environment.includes = [
    den.policies.env-collect-bgp-peers
    den.policies.env-collect-dns-resolvers
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
      dns-resolvers ? [ ],
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
        nodes = k3s-nodes;
        policies = gateway-policies;
      })
      (renderNetworkPolicies {
        inherit (unifi) site;
        policies = unifi.networkPolicies;
      })
      # Every environment's network, and every den host's reservation, lives on this one controller.
      (renderReservations {
        inherit (unifi) site;
        reservations = reservationsOf config.den.environments (
          lib.concatMap lib.attrValues (lib.attrValues config.den.hosts)
        );
      })
      (renderNetworkDns {
        inherit (unifi) site;
        inherit dns-resolvers;
        environments = lib.attrValues config.den.environments;
      })
      # Option 121 (docs/dns-resolver.md §7 Q2): the definition, and its value
      # for Default, laid over Default's PUT body (renderNetworkDns) in the field
      # named by the definition's _id.
      (renderDhcpOption {
        inherit (unifi) site;
        code = 121;
        name = "classless-routes";
        type = "hexarray";
      })
      {
        locals."unifi_network_${key net.unifiNetwork}_dns"."dhcpd_user_option_\${restapi_object.dhcp_option_classless_routes.id}" =
          "\${local.unifi_network_${key net.unifiNetwork}_classless_routes}";
        # This environment's network (Default): the cluster's LoadBalancer pool via
        # uplink (the route uplink-dev carries), then the default route via the gateway.
        locals."unifi_network_${key net.unifiNetwork}_classless_routes" = classlessRoutes [
          {
            destination = config.den.clusters.axon.networks.kubernetes-loadbalancers.cidr;
            router = lib.head (
              lib.splitString "/" (
                lib.head config.den.hosts.x86_64-linux.uplink.networking.interfaces.enp4s0.ipv4
              )
            );
          }
          {
            destination = "0.0.0.0/0";
            router = net.gatewayIp;
          }
        ];
      }
      {
        terraform = {
          # Versions are the provider packages' (terraformWrapper below), never stated here.
          required_providers = {
            unifi.source = "ubiquiti-community/unifi";
            # The gateway's custom NAT rules (v2 nat), which the unifi provider has no resource for.
            restapi.source = "Mastercard/restapi";
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
    {
      config,
      pkgs,
      self',
      ...
    }:
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

      # Each declared zone policy ($meta.policies) as an import block, by the one
      # live policy with its name and zone pair; none is created by the plan, and
      # two are refused (the firmware's zone migration fanned one legacy rule out
      # to every zone pair, so a pair is part of the match).
      policyImports = pkgs.writeText "unifi-policy-imports.jq" ''
        . as $live
        | (($zones | map({ (._id): .name }) | add) // {}) as $zone
        | [ ($meta.policies // {}) | to_entries[] | .key as $res | .value as $p
            | [ $live[] | select(.name == $p.name and $zone[.source.zone_id] == $p.source and $zone[.destination.zone_id] == $p.destination) ]
            | if length > 1 then error("unifi-adopt: \(length) live policies named \($p.name) from \($p.source) to \($p.destination); delete all but one")
              elif length == 1 then { to: "unifi_firewall_policy.\($res)", id: .[0]._id }
              else empty end ]
      '';

      # Each declared network ($meta.networks) as an import block, by the one live
      # networkconf with its name; restapi_object imports by its full path.
      networkImports = pkgs.writeText "unifi-network-imports.jq" ''
        . as $live
        | [ ($meta.networks // {}) | to_entries[] | .key as $res | .value as $n
            | [ $live[] | select(.name == $n) ]
            | if length != 1 then error("unifi-adopt: \(length) live networks named \($n); expected one")
              else { to: "restapi_object.\($res)", id: "/api/s/\($site)/rest/networkconf/\(.[0]._id)" } end ]
      '';

      # Each declared custom NAT rule ($meta.nat) as an import block, by the one
      # live rule with its description; restapi_object imports by its full path.
      natImports = pkgs.writeText "unifi-nat-imports.jq" ''
        . as $live
        | [ ($meta.nat // {}) | to_entries[] | .key as $res | .value.description as $d
            | [ $live[] | select(.description == $d) ]
            | if length > 1 then error("unifi-adopt: \(length) live NAT rules described \($d); delete all but one")
              elif length == 1 then { to: "restapi_object.\($res)", id: "/v2/api/site/\($site)/nat/\(.[0]._id)" }
              else empty end ]
      '';

      # Each declared DHCP option definition ($meta.dhcpOptions) as an import
      # block, by the one live definition with its code (its name is declared,
      # and a plan renames it); none is created here.
      dhcpOptionImports = pkgs.writeText "unifi-dhcp-option-imports.jq" ''
        . as $live
        | [ ($meta.dhcpOptions // {}) | to_entries[] | .key as $res | .value as $c
            | [ $live[] | select((.code | tostring) == ($c | tostring)) ]
            | if length > 1 then error("unifi-adopt: \(length) live DHCP options with code \($c); delete all but one")
              elif length == 1 then { to: "restapi_object.\($res)", id: "/api/s/\($site)/rest/dhcpoption/\(.[0]._id)" }
              else empty end ]
      '';

      # Each declared reservation ($meta.clients) as an import block, by the one
      # live client (rest/user) with its MAC, lowercased; restapi_object imports
      # by its full path. None is created here, and two are refused.
      clientImports = pkgs.writeText "unifi-client-imports.jq" ''
        . as $live
        | [ ($meta.clients // {}) | to_entries[] | .key as $res | .value as $m
            | [ $live[] | select((.mac // "" | ascii_downcase) == $m) ]
            | if length > 1 then error("unifi-adopt: \(length) live clients with MAC \($m); forget all but one")
              elif length == 1 then { to: "restapi_object.\($res)", id: "/api/s/\($site)/rest/user/\(.[0]._id)" }
              else empty end ]
      '';

      # Decrypts the API key and the state passphrase into this process's env only.
      secretsPrelude = ''
        cd "$(git rev-parse --show-toplevel)"
        # Generated by `tofu init` from the nix-provided providers; never carried over.
        rm -f ${workdir}/.terraform.lock.hcl
        identity=$(mktemp)
        trap 'rm -f "$identity"' EXIT
        age-plugin-yubikey -i > "$identity"
        [[ -s $identity ]] || { echo "no YubiKey identity found; plug in the YubiKey" >&2; exit 1; }
        UNIFI_API_KEY=$(age -d -i "$identity" .secrets/env/${unifiEnv}/unifi-api-key.age)
        TF_VAR_state_passphrase=$(age -d -i "$identity" .secrets/env/${unifiEnv}/unifi-state-passphrase.age)
        TF_VAR_unifi_api_key=$UNIFI_API_KEY
        export UNIFI_API_KEY TF_VAR_unifi_api_key TF_VAR_state_passphrase
      '';

      # Providers come from nixpkgs and pkgs/by-name, the only places a provider
      # version lives: required_providers takes it from the packages and the lock
      # file is not committed. nix-flake-update and update-pkgs are the provider bumps.
      unifiProvider = pkgs.terraform-providers.ubiquiti-community_unifi;
      restapi = self'.packages.terraform-provider-restapi;
      tofu = pkgs.opentofu.withPlugins (_: [
        unifiProvider
        restapi
      ]);

      # Each restapi_object import target the state already holds under another
      # id: the provider never drops an object deleted on the controller, and an
      # import block whose address is in state is skipped, so the stale entry
      # would stay and the live object would never be imported.
      staleImports = pkgs.writeText "unifi-stale-imports.jq" ''
        ([ $state.values.root_module.resources[]? | select(.mode == "managed") | { (.address): .values.id } ] | add // {}) as $ids
        | .import[] | select(.to | startswith("restapi_object."))
        | select($ids[.to] != null and $ids[.to] != (.id | split("/") | last))
        | "\(.to) \($ids[.to])"
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
        modules = unifiTerranixModules ++ [
          {
            terraform.required_providers = {
              unifi.version = unifiProvider.version;
              restapi.version = restapi.version;
            };
          }
        ];
        terraformWrapper.package = tofu;
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
            && builtins.attrNames rendered.resource.unifi_firewall_policy == [ "c1_https_ingress_allow" ]
            &&
              rendered.resource.unifi_firewall_policy.c1_https_ingress_allow == {
                name = "c1-https-ingress allow";
                action = "ALLOW";
                enabled = true;
                ip_version = "IPV4";
                protocol = "tcp_udp";
                source = {
                  zone_id = "\${data.unifi_firewall_zone.unifi_zone_external.id}";
                  matching_target = "ANY";
                  port_matching_type = "ANY";
                };
                destination = {
                  zone_id = "\${data.unifi_firewall_zone.unifi_zone_external.id}";
                  matching_target = "IP";
                  ips = [ "10.1.0.1" ];
                  port_matching_type = "SPECIFIC";
                  port = "443";
                };
              }
            && rendered.data.unifi_firewall_zone == { unifi_zone_external.name = "External"; }
            &&
              rendered._meta.policies.c1_https_ingress_allow == {
                name = "c1-https-ingress allow";
                source = "External";
                destination = "External";
              }
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

      # Fixture: a network policy renders one Internal -> Internal allow between
      # the networks' looked-up ids, its _meta entry and the network lookups, and
      # none renders nothing.
      checks.unifi-network-policy-render =
        let
          rendered = renderNetworkPolicies {
            site = "s";
            policies = [
              {
                name = "A to B";
                from = "A";
                to = "B";
                protocol = "all";
              }
            ];
          };
          endpoint = n: {
            zone_id = "\${data.unifi_firewall_zone.unifi_zone_internal.id}";
            matching_target = "NETWORK";
            network_ids = [ "\${data.restapi_object.unifi_network_${n}.id}" ];
            port_matching_type = "ANY";
          };
          ok =
            rendered.resource.unifi_firewall_policy == {
              a_to_b = {
                name = "A to B";
                protocol = "all";
                action = "ALLOW";
                enabled = true;
                ip_version = "IPV4";
                source = endpoint "a";
                destination = endpoint "b";
              };
            }
            &&
              rendered._meta.policies.a_to_b == {
                name = "A to B";
                source = "Internal";
                destination = "Internal";
              }
            &&
              builtins.attrNames rendered.data.restapi_object == [
                "unifi_network_a"
                "unifi_network_b"
              ]
            && rendered.data.restapi_object.unifi_network_a.search_value == "A"
            && rendered.data.unifi_firewall_zone == { unifi_zone_internal.name = "Internal"; }
            &&
              renderNetworkPolicies {
                site = "s";
                policies = [ ];
              } == { };
        in
        assert lib.assertMsg ok "unifi-network-policy-render:\n${builtins.toJSON rendered}";
        pkgs.writeText "unifi-network-policy-render" (builtins.toJSON rendered);

      # Fixture (docs/dns-resolver.md §2.4(a)): an environment's network renders the
      # full-body PUT of its live object with these exact DNS fields (Blocky, then
      # the gateway, padded to four; as IPv6 DNS Blocky's dns6, never the
      # gateway's own) and its dhcpRange as dhcpd_start/dhcpd_stop, its lookup,
      # import meta and review output; one with no unifiNetwork or no
      # dhcpResolvers renders none. The render reads dns.dhcpResolvers, never
      # dns.resolvers. Refused: an unknown instance and more than four servers.
      # Control: the payload predicate fails on the render without dhcpResolvers,
      # on one that reads dns.resolvers, on an instance with no dns6 and on one
      # from another environment (both render no IPv6 DNS), and on a network with
      # no dhcpRange (it renders no dhcpd_start/dhcpd_stop).
      # The workspace's Default overlay is the same fields plus option 121's value.
      checks.unifi-dhcp-dns-render =
        let
          # dns.resolvers names an instance the render must not pick.
          env = name: unifiNetwork: resolverNames: {
            inherit name;
            dns.resolvers = [ "r0" ];
            dns.dhcpResolvers = resolverNames;
            networks.default = {
              inherit unifiNetwork;
              gatewayIp = "10.0.0.1";
              dhcpRange = {
                start = "10.0.1.1";
                stop = "10.0.255.254";
              };
            };
          };
          args = {
            site = "s";
            dns-resolvers = [
              {
                name = "r0";
                dns = "10.0.10.0";
              }
              r1
            ];
            environments = [
              (env "t" "Default" [ "r1" ])
              (env "u" null [ "r1" ])
              (env "w" "lan2" [ ])
            ];
          };
          r1 = {
            name = "r1";
            environment = "t";
            dns = "10.0.10.1";
            dns6 = "fd00:0:10::1";
          };
          render = a: renderNetworkDns (args // a);
          rendered = render { };
          noDns6 = render {
            dns-resolvers = [ (removeAttrs r1 [ "dns6" ]) ];
            environments = [ (env "t" "Default" [ "r1" ]) ];
          };
          otherEnv = render {
            dns-resolvers = [ (r1 // { environment = "x"; }) ];
            environments = [ (env "t" "Default" [ "r1" ]) ];
          };
          refused = a: !(builtins.tryEval (builtins.deepSeq (render a) null)).success;
          live = "jsondecode(data.restapi_object.unifi_network_default.api_response)";
          byId = "/api/s/s/rest/networkconf/{id}";
          payloadOk =
            r:
            (r.locals or { }) == {
              unifi_network_default_dns = {
                dhcpd_dns_enabled = true;
                dhcpd_dns_1 = "10.0.10.1";
                dhcpd_dns_2 = "10.0.0.1";
                dhcpd_dns_3 = "";
                dhcpd_dns_4 = "";
                dhcpdv6_dns_auto = false;
                dhcpdv6_dns_1 = "fd00:0:10::1";
                dhcpdv6_dns_2 = "";
                dhcpdv6_dns_3 = "";
                dhcpdv6_dns_4 = "";
                dhcpd_start = "10.0.1.1";
                dhcpd_stop = "10.0.255.254";
              };
            };
          # Control: a network with no dhcpRange renders no range fields.
          noRange = render {
            environments = [
              (lib.recursiveUpdate (env "t" "Default" [ "r1" ]) { networks.default.dhcpRange = null; })
            ];
          };
          ok =
            payloadOk rendered
            &&
              rendered.resource.restapi_object == {
                network_default = {
                  path = "/api/s/s/rest/networkconf";
                  create_method = "PUT";
                  create_path = byId;
                  read_path = byId;
                  read_search = {
                    results_key = "data";
                    search_key = "_id";
                    search_value = "{id}";
                  };
                  update_path = byId;
                  destroy_method = "GET";
                  destroy_path = byId;
                  data = "\${jsonencode(merge(${live}, local.unifi_network_default_dns))}";
                  lifecycle = {
                    prevent_destroy = true;
                    precondition = [
                      {
                        condition = "\${alltrue([for k in [\"dhcpd_dns_enabled\",\"dhcpdv6_dns_auto\",\"dhcpd_start\",\"dhcpd_stop\"] : contains(keys(${live}), k)])}";
                        error_message = "unifi: network Default lacks one of dhcpd_dns_enabled, dhcpdv6_dns_auto, dhcpd_start, dhcpd_stop; read unifi-adopt's field list (docs/dns-resolver.md §7 Q4)";
                      }
                    ];
                  };
                };
              }
            &&
              rendered.data.restapi_object == {
                unifi_network_default = {
                  path = "/api/s/s/rest/networkconf";
                  results_key = "data";
                  search_key = "name";
                  search_value = "Default";
                  results_contains_object = true;
                };
              }
            && rendered._meta.networks == { network_default = "Default"; }
            && builtins.attrNames rendered.output.unifi_network_dns.value == [ "Default" ]
            && refused { environments = [ (env "t" "Default" [ "gone" ]) ]; }
            && refused {
              dns-resolvers = map (i: {
                name = "r${toString i}";
                dns = "10.0.10.${toString i}";
              }) (lib.range 1 4);
              environments = [
                (env "t" "Default" [
                  "r1"
                  "r2"
                  "r3"
                  "r4"
                ])
              ];
            }
            # Controls: the same payload predicate over an environment with no
            # dhcpResolvers, and over one whose dhcpResolvers is its dns.resolvers.
            && !(payloadOk (render {
              environments = [ (env "t" "Default" [ ]) ];
            }))
            && !(payloadOk (render {
              environments = [ (env "t" "Default" [ "r0" ]) ];
            }))
            && !(payloadOk noRange)
            && !(noRange.locals.unifi_network_default_dns ? dhcpd_start)
            && !(payloadOk noDns6)
            && noDns6.locals.unifi_network_default_dns.dhcpdv6_dns_1 == ""
            && !(payloadOk otherEnv)
            && otherEnv.locals.unifi_network_default_dns.dhcpdv6_dns_1 == ""
            # The workspace's Default overlay: these DNS fields and option 121's
            # value, keyed by the definition's _id.
            &&
              builtins.attrNames workspace == lib.sort lib.lessThan (
                builtins.attrNames rendered.locals.unifi_network_default_dns ++ [ userOption ]
              )
            && workspace.${userOption} == "\${local.unifi_network_default_classless_routes}";
          workspace = terraformConfiguration.config.locals.unifi_network_default_dns;
          userOption = "dhcpd_user_option_\${restapi_object.dhcp_option_classless_routes.id}";
        in
        assert lib.assertMsg ok "unifi-dhcp-dns-render:\n${builtins.toJSON rendered}";
        pkgs.writeText "unifi-dhcp-dns-render" (builtins.toJSON rendered);

      # Fixture (docs/dns-resolver.md §7 Q2, option 121): a definition renders
      # its POST, id path, by-id read and DELETE, and its adopt meta (the code);
      # classlessRoutes encodes RFC 3442's example widths (0, 8, 16, 24, 25,
      # 32) in uppercase hex and refuses host bits. The workspace's Default value
      # is the cluster's LB pool via uplink, then the default route via the
      # gateway, and Default's PUT carries it. Controls: the same predicate over
      # a /24 pool, and over the lowercase form, fails.
      checks.unifi-dhcp-option-render =
        let
          rendered = renderDhcpOption {
            site = "s";
            code = 121;
            name = "classless-routes";
            type = "hexarray";
          };
          r =
            destination:
            classlessRoutes [
              {
                inherit destination;
                router = "10.0.0.1";
              }
            ];
          live = terraformConfiguration.config.locals.unifi_network_default_classless_routes;
          defaultOk = v: v == "10:0A:0B:0A:0A:0A:01:00:0A:0A:00:01";
          inherit (terraformConfiguration.config) locals resource;
          ok =
            rendered == {
              resource.restapi_object.dhcp_option_classless_routes = {
                path = "/api/s/s/rest/dhcpoption";
                id_attribute = "data/0/_id";
                read_path = "/api/s/s/rest/dhcpoption/{id}";
                update_path = "/api/s/s/rest/dhcpoption/{id}";
                destroy_path = "/api/s/s/rest/dhcpoption/{id}";
                ignore_server_additions = true;
                data = builtins.toJSON {
                  code = 121;
                  name = "classless-routes";
                  type = "hexarray";
                  signed = false;
                };
              };
              _meta.dhcpOptions.dhcp_option_classless_routes = 121;
            }
            && r "0.0.0.0/0" == "00:0A:00:00:01"
            && r "10.0.0.0/8" == "08:0A:0A:00:00:01"
            && r "10.17.0.0/16" == "10:0A:11:0A:00:00:01"
            && r "10.27.129.0/24" == "18:0A:1B:81:0A:00:00:01"
            && r "10.229.0.128/25" == "19:0A:E5:00:80:0A:00:00:01"
            && r "10.198.122.47/32" == "20:0A:C6:7A:2F:0A:00:00:01"
            && !(builtins.tryEval (r "10.11.0.0/8")).success
            && !(builtins.tryEval (r "10.229.0.64/25")).success
            && defaultOk live
            && !(defaultOk (lib.toLower live))
            # Default's overlay carries it, and Default's PUT carries the overlay.
            && lib.hasInfix "local.unifi_network_default_classless_routes" (
              builtins.toJSON locals.unifi_network_default_dns
            )
            && lib.hasInfix "local.unifi_network_default_dns" resource.restapi_object.network_default.data
            && !(defaultOk (classlessRoutes [
              {
                destination = "10.11.0.0/24";
                router = "10.10.10.1";
              }
              {
                destination = "0.0.0.0/0";
                router = "10.10.0.1";
              }
            ]));
        in
        assert lib.assertMsg ok "unifi-dhcp-option-render:\n${builtins.toJSON rendered}\n${live}";
        pkgs.writeText "unifi-dhcp-option-render" (builtins.toJSON rendered);

      # Fixture (docs/address-plan.md §3 test 3): a host's reservation is the
      # interface holding its LAN IPv4, MAC lowercased; a host off every controller
      # network, or in an environment with no unifiNetwork, has none. A reservation
      # renders its MAC lookup, the full-body PUT of the live client with exactly
      # fixed_ip, name, use_fixedip and network_id laid over it, a destroy that
      # only clears use_fixedip, its review output and adopt meta. Refused: an
      # IPv4 with no MAC, and two hosts on one MAC. The workspace reserves each
      # den host with an IPv4 on a LAN, fixed_ip its addressOn: prod 5, dev 3.
      # Controls: the payload predicate fails on a reservation with another
      # address and on one with use_fixedip unset; the count predicate fails on
      # one host short.
      checks.unifi-reservation-render =
        let
          envs = {
            t.networks.default = {
              cidr = "10.0.0.0/16";
              unifiNetwork = "LAN 1";
            };
            u.networks.default = {
              cidr = "10.1.0.0/16";
              unifiNetwork = null;
            };
          };
          host = name: environment: interfaces: {
            inherit name environment;
            networking.interfaces = interfaces;
          };
          hosts = [
            (host "h1" "t" {
              eth0 = {
                ipv4 = [ "10.0.10.1/16" ];
                mac = "AA:BB:CC:00:00:01";
              };
            })
            (host "h2" "t" {
              wg0 = {
                ipv4 = [ "192.168.0.1/24" ];
                mac = null;
              };
            })
            (host "h3" "u" {
              eth0 = {
                ipv4 = [ "10.1.10.1/16" ];
                mac = null;
              };
            })
            (host "h4" "t" {
              lo.ipv4 = [ "172.16.0.4/32" ];
              br0 = {
                ipv4 = [ "10.0.10.4/16" ];
                mac = "aa:bb:cc:00:00:04";
              };
            })
          ];
          reservations = reservationsOf envs hosts;
          rendered = renderReservations {
            site = "s";
            inherit reservations;
          };
          refused = hs: !(builtins.tryEval (builtins.deepSeq (reservationsOf envs hs) null)).success;
          live = "jsondecode(data.restapi_object.unifi_client_h1.api_response)";
          byId = "/api/s/s/rest/user/{id}";
          payloadOk =
            r:
            r.locals.unifi_client_h1_fixed or null == {
              name = "h1";
              fixed_ip = "10.0.10.1";
              use_fixedip = true;
              network_id = "\${data.restapi_object.unifi_network_lan_1.id}";
            };
          withRes =
            f:
            renderReservations {
              site = "s";
              reservations = map (r: if r.name == "h1" then f r else r) reservations;
            };

          # The workspace: one reservation per den host with an IPv4 on a LAN.
          inherit (terraformConfiguration.config) locals;
          fixed = lib.filterAttrs (n: _: lib.hasPrefix "unifi_client_" n) locals;
          denHosts = lib.concatMap lib.attrValues (lib.attrValues fleet.hosts);
          onLan = lib.filter (
            h:
            let
              net = fleet.environments.${h.environment}.networks.default or null;
            in
            net != null
            && lib.any (plan.ipv4InCidr net.cidr) (
              lib.concatMap (i: map (a: lib.head (lib.splitString "/" a)) i.ipv4) (
                lib.attrValues h.networking.interfaces
              )
            )
          ) denHosts;
          countOk = fs: hs: lib.length (lib.attrNames fs) == lib.length hs && lib.length hs == 8;
          workspaceOk = lib.all (
            h:
            (fixed."unifi_client_${key h.name}_fixed".fixed_ip or null)
            == fleet.environments.${h.environment}.addressOn "default" h
          ) onLan;
          ok =
            map (r: r.name) reservations == [
              "h1"
              "h4"
            ]
            &&
              lib.findFirst (r: r.name == "h1") null reservations == {
                name = "h1";
                ip = "10.0.10.1";
                mac = "aa:bb:cc:00:00:01";
                network = "LAN 1";
              }
            && payloadOk rendered
            &&
              rendered.resource.restapi_object.client_h1 == {
                path = "/api/s/s/rest/user";
                create_method = "PUT";
                create_path = byId;
                read_path = byId;
                read_search = {
                  results_key = "data";
                  search_key = "_id";
                  search_value = "{id}";
                };
                update_path = byId;
                destroy_method = "PUT";
                destroy_path = byId;
                data = "\${jsonencode(merge(${live}, local.unifi_client_h1_fixed))}";
                destroy_data = "\${jsonencode(merge(${live}, { use_fixedip = false }))}";
              }
            &&
              rendered.data.restapi_object.unifi_client_h1 == {
                path = "/api/s/s/rest/user";
                results_key = "data";
                search_key = "mac";
                search_value = "aa:bb:cc:00:00:01";
                results_contains_object = true;
              }
            && rendered.data.restapi_object.unifi_network_lan_1.search_value == "LAN 1"
            &&
              rendered._meta.clients == {
                client_h1 = "aa:bb:cc:00:00:01";
                client_h4 = "aa:bb:cc:00:00:04";
              }
            &&
              builtins.attrNames rendered.output.unifi_reservations.value == [
                "h1"
                "h4"
              ]
            &&
              renderReservations {
                site = "s";
                reservations = [ ];
              } == { }
            && refused (
              hosts
              ++ [
                (host "h5" "t" {
                  eth0 = {
                    ipv4 = [ "10.0.10.5/16" ];
                    mac = null;
                  };
                })
              ]
            )
            && refused (
              hosts
              ++ [
                (host "h6" "t" {
                  eth0 = {
                    ipv4 = [ "10.0.10.6/16" ];
                    mac = "AA:BB:CC:00:00:01";
                  };
                })
              ]
            )
            # Controls.
            && !(payloadOk (withRes (r: r // { ip = "10.0.10.9"; })))
            && !(payloadOk (
              rendered
              // {
                locals.unifi_client_h1_fixed = removeAttrs rendered.locals.unifi_client_h1_fixed [ "use_fixedip" ];
              }
            ))
            && countOk fixed onLan
            && workspaceOk
            && !(countOk fixed (lib.tail onLan));
        in
        assert lib.assertMsg ok
          "unifi-reservation-render:\n${builtins.toJSON rendered}\n${builtins.toJSON fixed}";
        pkgs.writeText "unifi-reservation-render" (builtins.toJSON rendered);

      # Fixture: a policy renders one Internal -> Internal zone policy and one
      # address group per source environment from its cluster's node addresses,
      # drops the legacy rule of that name from state, a same-environment source
      # renders none, and an unknown cluster is refused.
      checks.unifi-gateway-policy-render =
        let
          node = clusterName: env: ip: {
            inherit clusterName ip;
            environment.name = env;
          };
          args = {
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
          inherit (rendered.resource) unifi_firewall_policy unifi_firewall_group;
          refused =
            a: !(builtins.tryEval (builtins.deepSeq (renderGatewayPolicies (args // a)) null)).success;
          ok =
            builtins.attrNames unifi_firewall_policy == [ "svc_to_h_from_p" ]
            &&
              unifi_firewall_policy.svc_to_h_from_p == {
                name = "svc-to-h from p";
                action = "ALLOW";
                enabled = true;
                ip_version = "IPV4";
                protocol = "tcp";
                source = {
                  zone_id = "\${data.unifi_firewall_zone.unifi_zone_internal.id}";
                  matching_target = "IP";
                  ip_group_id = "\${unifi_firewall_group.svc_to_h_from_p.id}";
                  port_matching_type = "ANY";
                };
                destination = {
                  zone_id = "\${data.unifi_firewall_zone.unifi_zone_internal.id}";
                  matching_target = "IP";
                  ips = [ "10.2.0.9" ];
                  port_matching_type = "SPECIFIC";
                  port = "8081";
                };
              }
            &&
              rendered.removed == [
                {
                  from = "unifi_firewall_rule.svc_to_h_from_p";
                  lifecycle.destroy = false;
                }
              ]
            && rendered.data.unifi_firewall_zone == { unifi_zone_internal.name = "Internal"; }
            &&
              unifi_firewall_group == {
                svc_to_h_from_p = {
                  name = "svc-to-h from p";
                  type = "address-group";
                  members = [
                    "10.1.0.2"
                    "10.1.0.3"
                  ];
                };
              }
            && refused { policies = map (p: p // { sources.clusters = [ "c3" ]; }) args.policies; };
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
              tofu
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
              policies=$(curl -fksS -H @<(printf 'X-Api-Key: %s\n' "$UNIFI_API_KEY") \
                "$api/proxy/network/v2/api/site/$site/firewall-policies")
              zones=$(curl -fksS -H @<(printf 'X-Api-Key: %s\n' "$UNIFI_API_KEY") \
                "$api/proxy/network/v2/api/site/$site/firewall/zone")
              pol=$(jq --argjson zones "$zones" --argjson meta "$(< ${meta})" -f ${policyImports} <<<"$policies")
              nat=$(curl -fksS -H @<(printf 'X-Api-Key: %s\n' "$UNIFI_API_KEY") \
                "$api/proxy/network/v2/api/site/$site/nat" \
                | jq --arg site "$site" --argjson meta "$(< ${meta})" -f ${natImports})
              netconf=$(curl -fksS -H @<(printf 'X-Api-Key: %s\n' "$UNIFI_API_KEY") \
                "$api/proxy/network/api/s/$site/rest/networkconf" | jq .data)
              net=$(jq --arg site "$site" --argjson meta "$(< ${meta})" -f ${networkImports} <<<"$netconf")
              dhcpopts=$(curl -fksS -H @<(printf 'X-Api-Key: %s\n' "$UNIFI_API_KEY") \
                "$api/proxy/network/api/s/$site/rest/dhcpoption" | jq .data)
              dhcpopt=$(jq --arg site "$site" --argjson meta "$(< ${meta})" -f ${dhcpOptionImports} <<<"$dhcpopts")
              users=$(curl -fksS -H @<(printf 'X-Api-Key: %s\n' "$UNIFI_API_KEY") \
                "$api/proxy/network/api/s/$site/rest/user" | jq .data)
              clients=$(jq --arg site "$site" --argjson meta "$(< ${meta})" -f ${clientImports} <<<"$users")
              # unifi_bgp is a per-site singleton; its import id is the site name.
              # A port forward imports by its controller _id. Its config is the
              # declared one (port-forwards); a live forward with none fails the plan.
              # A zone policy imports by its _id, a custom NAT rule by its path.
              jq --arg site "$site" --argjson pf "$(jq -f ${portForwardImports} <<<"$pfs")" \
                --argjson pol "$pol" --argjson nat "$nat" --argjson net "$net" --argjson dhcpopt "$dhcpopt" \
                --argjson clients "$clients" \
                '{ import: ([ { to: .bgp, id: $site } ] + $pf + $pol + $nat + $net + $dhcpopt + $clients) }' \
                ${meta} > ${workdir}/imports.tf.json
              # The flake reads imports.tf.json only once git tracks it.
              git add ${workdir}/imports.tf.json
              # Drop each stale restapi_object entry, so the plan imports the live object
              # in its place instead of keeping (or re-creating) the vanished one.
              ${lib.getExe scripts.init} -input=false >/dev/null
              stale=$(jq -r --argjson state "$(tofu -chdir=${workdir} show -json)" -f ${staleImports} ${workdir}/imports.tf.json)
              while read -r res id; do
                [[ -n $res ]] || continue
                tofu -chdir=${workdir} state rm "$res" >/dev/null
                echo "unifi-adopt: dropped $res from state: its id $id is not the live object's"
              done <<<"$stale"
              echo "unifi-adopt: site $site BGP config $(jq -r '.[0]._id' <<<"$bgp") ($(jq -r '.[0].description' <<<"$bgp"))"
              echo "unifi-adopt: $(jq length <<<"$pfs") port forwards:"
              jq -r '.[] | "  \(.name // "-")\t\(.proto)\twan \(.pfwd_interface // "-"):\(.dst_port // "-")\t-> \(.fwd // "-"):\(.fwd_port // "-")\tenabled=\(.enabled)"' <<<"$pfs"
              # The DNS-related fields of each declared network, as the controller
              # holds them: which carry DHCP DNS, RA RDNSS and DHCPv6 DNS (§7 Q4).
              echo "unifi-adopt: networks' DNS, RA and DHCPv6 fields (docs/dns-resolver.md §7 Q4):"
              jq -r --argjson meta "$(< ${meta})" '
                ($meta.networks // {} | to_entries | map(.value)) as $names
                | .[] | select(.name as $n | $names | index($n))
                | "  \(.name) (\(._id))", (to_entries[]
                  | select(.key | test("dns|ipv6|_ra|rdnss|slaac|dhcpdv6|radvd"; "i"))
                  | "    \(.key) = \(.value | tojson)")' <<<"$netconf"
              # The option-121 experiment (§7 Q2): every custom DHCP option definition,
              # then each declared network's DHCP-option fields (dhcpd_*, or keys naming
              # a declared definition or its code), which reveal where a value lives.
              echo "unifi-adopt: $(jq length <<<"$dhcpopts") DHCP option definitions (rest/dhcpoption):"
              jq -r '.[] | "  \(.name)\tcode=\(.code)\ttype=\(.type)\twidth=\(.width // "-")\tsigned=\(.signed)\t\(._id)"' <<<"$dhcpopts"
              echo "unifi-adopt: networks' DHCP option fields:"
              jq -r --argjson meta "$(< ${meta})" --argjson opts "$dhcpopts" '
                ($meta.networks // {} | to_entries | map(.value)) as $names
                | ([ $opts[] | .name, .code, ._id ] | map(tostring | ascii_downcase)) as $needles
                | .[] | select(.name as $n | $names | index($n))
                | "  \(.name) (\(._id))", (to_entries[]
                  | select(.key | ascii_downcase | . as $k
                      | (test("^dhcpd_") and (test("dns") | not)) or any($needles[]; . as $s | $k | contains($s)))
                  | "    \(.key) = \(.value | tojson)")' <<<"$netconf"
              # Each declared reservation's live client record, as the controller holds
              # it (docs/address-plan.md §2.3), and whether it is imported.
              echo "unifi-adopt: $(jq length <<<"$clients") of $(jq '.clients // {} | length' ${meta}) reservations to import (rest/user):"
              jq -r --argjson meta "$(< ${meta})" --argjson nets "$netconf" '
                (($nets | map({ (._id): .name }) | add) // {}) as $net
                | . as $live
                | ($meta.clients // {}) | to_entries[] | .key as $res | .value as $m
                | [ $live[] | select((.mac // "" | ascii_downcase) == $m) ] as $c
                | if ($c | length) == 0 then "  \($res)\t\($m)\tno live client: the plan fails at its lookup until the host is seen"
                  else $c[] | "  \($res)\t\($m)\t\(._id)\tname=\(.name // "-" | tojson)\tnetwork=\($net[.network_id // ""] // .network_id // "-")\tuse_fixedip=\(.use_fixedip // false)\tfixed_ip=\(.fixed_ip // "-")\tlast_ip=\(.last_ip // "-")" end' <<<"$users"
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
