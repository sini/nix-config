# The address plan's pure checks (docs/address-plan.md §3), each with a control
# that must fail or throw:
#   address-plan-slices  every environment's (purpose) /64s, as GUA subnet ids and
#                        site-ULA subnets, lie in its own /60 and overlap no other;
#                        prod's LAN ULA is Blocky's fd3d:f136:2e4e::/64 exactly; the
#                        fleet yields 2 × 3 slices. Controls: two environments on
#                        one nibble, and a nibble of 16, throw; each cluster's pod
#                        and service IPv6 and its nodes' fabric loopbacks lie in
#                        its environment's P = 2 slice (control: fdfd:cafe::/48's
#                        old pod range fails)
#   address-plan-tokens  every den host's IPv4 on its LAN is its token, unique
#                        site-wide with a non-zero first group (prod 5, dev 3);
#                        each LAN unit, the guests' hand-written 20-lan included,
#                        carries Token, DHCPv6Client = false and the token's ULA;
#                        only uplink's br0 sends RAs. Controls: a duplicate IPv4
#                        throws, a 0.x address fails the first-group predicate, a
#                        wrong token fails the unit predicate, and a second
#                        RA-sending unit fails the RA predicate
#   nix build .#checks.x86_64-linux.address-plan-slices .#checks.x86_64-linux.address-plan-tokens
{ config, lib, ... }:
let
  plan = import ./_address-plan.nix { inherit lib; };

  # Every (environment, purpose) slice of the environments with a nibble.
  slicesOf =
    envs:
    let
      withNibble = lib.filter (e: e.ipv6Nibble or null != null) envs;
      byNibble = lib.groupBy (e: toString e.ipv6Nibble) withNibble;
      shared = lib.filterAttrs (_: es: lib.length es > 1) byNibble;
    in
    if shared != { } then
      throw "address-plan: environments ${
        lib.concatMapStringsSep ", " (es: lib.concatMapStringsSep "/" (e: e.name) es) (
          lib.attrValues shared
        )
      } share a nibble"
    else
      lib.concatMap (
        e:
        lib.mapAttrsToList (purpose: p: rec {
          env = e.name;
          inherit purpose;
          nibble = e.ipv6Nibble;
          id = plan.subnetId e.ipv6Nibble p;
          gua = plan.subnetHex id;
          ula = plan.ulaSubnet id;
        }) plan.purposes
      ) withNibble;

  slices = slicesOf (lib.attrValues config.den.environments);
  ulaHead = lib.removeSuffix "::/48" plan.ula;
  slicesOk =
    ss:
    lib.length ss == 2 * lib.length (lib.attrNames plan.purposes)
    && lib.length (lib.unique (map (s: s.id) ss)) == lib.length ss
    && lib.length (lib.unique (map (s: s.ula) ss)) == lib.length ss
    # Inside its own /60: the id's high nibble is the environment's.
    && lib.all (s: s.id / 16 == s.nibble && s.id < 256) ss
    && lib.all (s: lib.hasPrefix "${ulaHead}:" s.ula && lib.hasSuffix "::/64" s.ula) ss;
  throws = v: !(builtins.tryEval (builtins.deepSeq v null)).success;
  fixture = name: ipv6Nibble: { inherit name ipv6Nibble; };
  prodLan = config.den.environments.prod.networks.default.ipv6_cidr;

  # A cluster's IPv6 (pods, services, its nodes' fabric loopbacks) inside its
  # environment's cluster slice.
  inClusterSlice =
    env: a: lib.hasPrefix "${plan.clusterUla config.den.environments.${env}.ipv6Nibble}:" a;
  clusterAddrs =
    c:
    lib.filter (a: a != null) (map (n: n.ipv6_cidr or null) (lib.attrValues c.networks))
    ++ lib.concatMap (
      h:
      lib.optional (
        h.settings.services.k3s.clusterName or null == c.name
      ) h.settings.services.networking.thunderbolt-mesh-of.loopback.ipv6 or null
    ) (lib.concatMap lib.attrValues (lib.attrValues config.den.hosts));
  clusterOk = c: lib.all (inClusterSlice c.environment) (lib.filter (a: a != null) (clusterAddrs c));

  checks = {
    slices = slicesOk slices;
    clustersInSlice =
      lib.all clusterOk (lib.attrValues config.den.clusters)
      && lib.length (lib.filter (a: a != null) (clusterAddrs config.den.clusters.axon)) == 5;
    oldPodRangeFails = !(inClusterSlice "prod" "fdfd:cafe:00:0001::/96");
    prodLanIsBlockys = prodLan == "fd3d:f136:2e4e::/64";
    devLanIsSubnet10 =
      config.den.environments.dev.networks.default.ipv6_cidr == "fd3d:f136:2e4e:10::/64";
    lanUlaIsSlice = lib.all (
      s: s.purpose != "lan" || config.den.environments.${s.env}.networks.default.ipv6_cidr == s.ula
    ) slices;
    guaIds =
      lib.sort lib.lessThan (map (s: s.gua) slices) == [
        "0"
        "1"
        "10"
        "11"
        "12"
        "2"
      ];
    # Controls.
    sharedNibbleThrows = throws (slicesOf [
      (fixture "a" 0)
      (fixture "b" 0)
    ]);
    nibble16Throws = throws (slicesOf [ (fixture "a" 16) ]);
    oneEnvFails = !(slicesOk (slicesOf [ (fixture "a" 0) ]));
    overlapFails = !(slicesOk (lib.init slices ++ [ (lib.head slices // { env = "x"; }) ]));
    foreignSliceFails = !(slicesOk (lib.init slices ++ [ (lib.last slices // { nibble = 5; }) ]));
  };

  # Every host with an IPv4 on its environment's LAN, with its token. Two hosts
  # on one token are refused.
  tokensOf =
    envs: hosts:
    let
      rows = lib.concatMap (
        h:
        let
          net = (envs.${h.environment} or { }).networks.default or null;
          ips = lib.concatMap (i: map (a: lib.head (lib.splitString "/" a)) (i.ipv4 or [ ])) (
            lib.attrValues (h.networking.interfaces or { })
          );
        in
        if net == null then
          [ ]
        else
          map (ip: {
            host = h.name;
            env = h.environment;
            inherit ip;
            token = plan.tokenOf ip;
          }) (lib.filter (plan.ipv4InCidr net.cidr) ips)
      ) hosts;
      shared = lib.filterAttrs (_: rs: lib.length rs > 1) (lib.groupBy (r: r.token) rows);
    in
    if shared != { } then
      throw "address-plan: hosts share a token: ${
        lib.concatMapStringsSep ", " (rs: lib.concatMapStringsSep "/" (r: r.host) rs) (
          lib.attrValues shared
        )
      }"
    else
      rows;
  allHosts = lib.concatMap lib.attrValues (lib.attrValues config.den.hosts);
  tokens = tokensOf config.den.environments allHosts;
  countIn = env: lib.length (lib.filter (t: t.env == env) tokens);
  firstGroupNonZero = t: builtins.match "::[1-9][0-9]*:.*" t.token != null;
  tokenOfHost =
    h: (lib.findFirst (t: t.host == h) (throw "address-plan: no token for ${h}") tokens).token;

  # The LAN units as rendered: each host's, and each guest's hand-written 20-lan.
  nixos = config.flake.nixosConfigurations;
  netsOf = c: c.config.systemd.network.networks;
  guestNets = parent: g: netsOf { config = nixos.${parent}.config.microvm.vms.${g}.config.config; };
  units = {
    uplink = (netsOf nixos.uplink).br0;
    axon-01 = (netsOf nixos.axon-01).enp2s0;
    axon-02 = (netsOf nixos.axon-02).enp2s0;
    axon-03 = (netsOf nixos.axon-03).enp2s0;
    cortex = (netsOf nixos.cortex).br0;
    bitstream = (netsOf nixos.bitstream).bond0;
    uplink-dev = (guestNets "uplink" "uplink-dev")."20-lan";
    cortex-cuda = (guestNets "cortex" "cortex-cuda")."20-lan";
  };
  uplinkHost = lib.findFirst (x: x.name == "uplink") null allHosts;
  envOf = h: config.den.environments.${(lib.findFirst (x: x.name == h) null allHosts).environment};
  unitOk =
    h: token: u:
    u.ipv6AcceptRAConfig.Token or null == "static:${token}"
    && u.ipv6AcceptRAConfig.DHCPv6Client or null == false
    && lib.elem (plan.addressIn (envOf h).networks.default.ipv6_cidr token) u.networkConfig.Address
    && u.ipv6AcceptRAConfig.UseAutonomousPrefix or true;
  # Every unit of these hosts that sends RAs, as host/unit.
  raSenders =
    nets:
    lib.concatLists (
      lib.mapAttrsToList (
        h: ns:
        lib.mapAttrsToList (n: _: "${h}/${n}") (
          lib.filterAttrs (_: u: u.networkConfig.IPv6SendRA or false) ns
        )
      ) nets
    );
  allNets = {
    uplink = netsOf nixos.uplink;
    axon-01 = netsOf nixos.axon-01;
    axon-02 = netsOf nixos.axon-02;
    axon-03 = netsOf nixos.axon-03;
    cortex = netsOf nixos.cortex;
    bitstream = netsOf nixos.bitstream;
    uplink-dev = guestNets "uplink" "uplink-dev";
    cortex-cuda = guestNets "cortex" "cortex-cuda";
  };
  raOk = nets: raSenders nets == [ "uplink/br0" ];

  tokenChecks = {
    prodCount = countIn "prod" == 5;
    devCount = countIn "dev" == 3;
    unique = lib.length (lib.unique (map (t: t.token) tokens)) == lib.length tokens;
    nonZeroFirstGroup = tokens != [ ] && lib.all firstGroupNonZero tokens;
    uplinkToken = tokenOfHost "uplink" == "::10:10:10:1";
    cortexUla =
      plan.addressIn (envOf "cortex").networks.default.ipv6_cidr (tokenOfHost "cortex")
      == "fd3d:f136:2e4e:10:10:9:2:1/64";
    unitsCarryTokens = lib.all (h: unitOk h (tokenOfHost h) units.${h}) (lib.attrNames units);
    unitsCover =
      lib.sort lib.lessThan (lib.attrNames units) == lib.sort lib.lessThan (map (t: t.host) tokens);
    onlyUplinkSendsRA = raOk allNets;
    # Controls.
    duplicateIpThrows = throws (
      tokensOf config.den.environments [
        uplinkHost
        (uplinkHost // { name = "twin"; })
      ]
    );
    zeroFirstOctetFails = !(firstGroupNonZero { token = plan.tokenOf "0.10.10.1"; });
    wrongTokenFails = !(unitOk "uplink" (tokenOfHost "axon-01") units.uplink);
    secondRaSenderFails =
      !(raOk (
        allNets
        // {
          axon-01 = allNets.axon-01 // {
            x.networkConfig.IPv6SendRA = true;
          };
        }
      ));
  };
  failedTokens = lib.attrNames (lib.filterAttrs (_: ok: !ok) tokenChecks);
  failed = lib.attrNames (lib.filterAttrs (_: ok: !ok) checks);
in
{
  perSystem =
    { pkgs, system, ... }:
    {
      checks.address-plan-slices = pkgs.runCommand "address-plan-slices" { } ''
        failed=${lib.escapeShellArg (lib.concatStringsSep " " failed)}
        if [ -n "$failed" ]; then
          echo "address-plan-slices: failed: $failed" >&2
          exit 1
        fi
        echo "address-plan-slices: ${toString (lib.length (lib.attrNames checks))} properties hold"
        touch $out
      '';
      # The rendered units are x86_64-linux hosts'.
      checks.address-plan-tokens = lib.mkIf (system == "x86_64-linux") (
        pkgs.runCommand "address-plan-tokens" { } ''
          failed=${lib.escapeShellArg (lib.concatStringsSep " " failedTokens)}
          if [ -n "$failed" ]; then
            echo "address-plan-tokens: failed: $failed" >&2
            exit 1
          fi
          echo "address-plan-tokens: ${toString (lib.length (lib.attrNames tokenChecks))} properties hold"
          touch $out
        ''
      );
    };
}
