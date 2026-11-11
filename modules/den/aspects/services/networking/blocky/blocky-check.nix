# The resolver's pure checks (docs/dns-resolver.md §3), over uplink's rendered
# Blocky settings, each with a negative control that must fail the same predicate:
#   blocky-lists   test 9: every list source is an https URL; a bare path fails
#                  it, while `blocky validate` alone accepts that path
#   blocky-render  test 9: an empty allowlist renders no `allowlists` key;
#                  test 2: no domain literal in this aspect, the served names come
#                  from den and match CoreDNS's hosts plugin exactly;
#                  test 11: only a resolver host collects served-domains and
#                  dns-internal (read at the collection policy);
#                  §2.4(a): prod's ULA is RFC 4193 (fd, the hash-derived 40-bit
#                  global ID, a /64), Blocky listens on its ::53, and uplink's br0
#                  holds that address without DAD and advertises the prefix
#                  on-link only; ipv6On's controls: another /64 of the same /48
#                  and uplink's ISP address both fall outside it
#   nix build .#checks.x86_64-linux.blocky-lists .#checks.x86_64-linux.blocky-render
{ config, lib, ... }:
let
  nixos = config.flake.nixosConfigurations.uplink;
  blocky = nixos.config.services.blocky;
  rendered = blocky.settings;
  prod = config.den.environments.prod;
  hosts = config.den.hosts.x86_64-linux;
  render = import ./_settings.nix { inherit lib; };

  # §2.4(a): the ULA and Blocky's address in it.
  ula = prod.networks.default.ipv6_cidr;
  globalId = builtins.substring 0 10 (builtins.hashString "sha256" "${prod.domain}/prod");
  at = suffix: builtins.replaceStrings [ "::/64" ] [ suffix ] ula;
  blockyUla = at "::53";
  br0 = nixos.config.systemd.network.networks.br0;
  ipv6On = prod.ipv6On "default";

  # Test 9: denylists, and allowlists that are not inline (no newline), are https URLs.
  listsOk =
    s:
    let
      sources =
        lib.concatLists (lib.attrValues (s.blocking.denylists or { }))
        ++ lib.filter (e: !(lib.hasInfix "\n" e)) (
          lib.concatLists (lib.attrValues (s.blocking.allowlists or { }))
        );
    in
    sources != [ ] && lib.all (lib.hasPrefix "https://") sources;
  barePath = lib.recursiveUpdate rendered { blocking.denylists.default = [ "wildcard/pro.txt" ]; };

  sample = {
    upstreams = [ "192.0.2.1#resolver.invalid" ];
    internalNames = [ ];
    internalResolver = "192.0.2.53";
    tailnetDomain = "ts.invalid";
    cachePath = "/var/lib/blocky";
    dnsListen = [ "192.0.2.10:53" ];
    httpListen = [ "192.0.2.10:4000" ];
  };
  withAllowlist =
    allowlist:
    render (
      sample
      // {
        filter = {
          denylists = [ ];
          inherit allowlist;
        };
      }
    );

  # Test 2: CoreDNS's hosts plugin over the same served-domains records.
  corednsServers =
    config.flake.nixidyEnvs.x86_64-linux.axon.config.applications.coredns.helm.releases.coredns.values.servers;
  hostsBlock =
    (lib.findFirst (p: p.name == "hosts") null (lib.head corednsServers).plugins).configBlock;
  corednsNames = lib.sort lib.lessThan (
    map (l: lib.last (lib.splitString " " l)) (
      lib.filter (l: l != "fallthrough") (lib.splitString "\n" hostsBlock)
    )
  );
  tailnetDomain = "ts.${prod.domain}";
  mapped = rendered.conditional.mapping;
  servedNames = lib.sort lib.lessThan (lib.attrNames (removeAttrs mapped [ tailnetDomain ]));
  internalAddress =
    config.den.clusters.axon.networks.kubernetes-loadbalancers.assignments.coredns-internal;
  namesMatch = names: names != [ ] && names == corednsNames;
  aspectSources = lib.filterAttrs (n: t: t == "regular" && lib.hasSuffix ".nix" n) (
    builtins.readDir ./.
  );
  # The domain's first label, read from den so this file holds no literal either.
  domainLabel = lib.head (lib.splitString "." prod.domain);
  noDomainLiteral = lib.all (n: !(lib.hasInfix domainLabel (builtins.readFile (./. + "/${n}")))) (
    lib.attrNames aspectSources
  );

  # Test 11: the guarded policy collects for a resolver host and for no other.
  policy = config.den.policies.collect-resolver-inputs.fn;
  collects = host: policy { inherit host; } != [ ];
  asResolver =
    host:
    host
    // {
      settings = lib.recursiveUpdate host.settings { services.networking.blocky.isResolver = true; };
    };

  checks = {
    allowlistEmptyOmitted = !((withAllowlist [ ]).blocking ? allowlists);
    allowlistInline =
      (withAllowlist [
        "a.invalid"
        "b.invalid"
      ]).blocking.allowlists.default == [ "a.invalid\nb.invalid\n" ];
    uplinkAllowlistOmitted = !(rendered.blocking ? allowlists);
    inherit noDomainLiteral;
    renderedHoldsGrafana = mapped ? "grafana.${prod.domain}";
    servedNamesMatchCoredns = namesMatch servedNames;
    servedNamesMissingOneFails = !(namesMatch (lib.tail servedNames));
    servedNamesToCorednsInternal = lib.all (n: mapped.${n} == internalAddress) servedNames;
    tailnetToQuad100 = mapped.${tailnetDomain} == "100.100.100.100";
    uplinkCollects = collects hosts.uplink;
    axonCollectsNothing = !(collects hosts.axon-01);
    axonUnguardedCollects = collects (asResolver hosts.axon-01);
    ulaIsRfc4193 =
      builtins.match "fd[0-9a-f]{2}:[0-9a-f]{4}:[0-9a-f]{4}::/64" ula != null
      && lib.concatStrings (lib.splitString ":" (lib.removePrefix "fd" (at ""))) == globalId;
    listensOnUla = lib.elem "[${blockyUla}]:53" rendered.ports.dns;
    br0UlaWithoutDad =
      br0.addresses == [
        {
          Address = "${blockyUla}/64";
          DuplicateAddressDetection = "none";
        }
      ]
      && !(lib.elem "${blockyUla}/64" br0.networkConfig.Address);
    br0AdvertisesUlaOnLink =
      br0.networkConfig.IPv6SendRA
      && br0.networkConfig.IPv6AcceptRA
      &&
        br0.ipv6Prefixes == [
          {
            Prefix = ula;
            AddressAutoconfiguration = false;
          }
        ]
      && br0.ipv6SendRAConfig.RouterLifetimeSec == 0
      && !br0.ipv6SendRAConfig.EmitDNS;
    ipv6OnHoldsBlocky = ipv6On [ "${blockyUla}/64" ] == [ "${blockyUla}/64" ];
    ipv6OnOtherSubnetFails = ipv6On [ (at ":1::53/64") ] == [ ];
    ipv6OnIspAddressFails = ipv6On [ "2001:5a8:608c:b600::271/128" ] == [ ];
  };
  failed = lib.attrNames (lib.filterAttrs (_: ok: !ok) checks);
  yaml = name: s: (nixos.pkgs.formats.yaml { }).generate name s;
in
{
  perSystem =
    { pkgs, system, ... }:
    {
      checks = lib.optionalAttrs (system == nixos.pkgs.stdenv.hostPlatform.system) {
        blocky-lists = pkgs.runCommand "blocky-lists" { } ''
          ${lib.optionalString (!(listsOk rendered)) ''
            echo "blocky-lists: a rendered list source is not an https URL" >&2
            exit 1
          ''}
          ${lib.optionalString (listsOk barePath) ''
            echo "blocky-lists: control: a bare-path denylist passes the URL predicate" >&2
            exit 1
          ''}
          # The control's other half: validate alone does not catch the bare path.
          ${lib.getExe blocky.package} --config ${yaml "bare-path.yaml" barePath} validate
          echo "blocky-lists: sources are https URLs; a bare path fails the predicate and passes validate"
          touch $out
        '';
        blocky-render = pkgs.runCommand "blocky-render" { } ''
          failed=${lib.escapeShellArg (lib.concatStringsSep " " failed)}
          if [ -n "$failed" ]; then
            echo "blocky-render: failed: $failed" >&2
            exit 1
          fi
          echo "blocky-render: ${toString (lib.length (lib.attrNames checks))} properties hold"
          touch $out
        '';
      };
    };
}
