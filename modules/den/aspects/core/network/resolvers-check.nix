# The client side of the filtering resolver (docs/dns-resolver.md §3), each
# property with a control that must fail the same predicate:
#   dns-clients  test 5 (eval part): every static host's and guest's LAN link
#                lists exactly Blocky then its gateway, in plain DNS, with no
#                RDNSS, and tailscale takes --accept-dns=false; blade (roaming)
#                keeps the DoT upstreams and MagicDNS. Controls: the same
#                predicates over dns.resolvers = [ ] and over blade fail.
#                test 11 (eval part): every host collects dns-resolvers, by design.
#   dns-d10      test 7: the hard-coded resolver grep matches nothing in
#                modules/den. Controls: it matches the five removed sites, and
#                not the environment files' "#name" upstreams or acme resolver.
#   nix build .#checks.x86_64-linux.dns-clients .#checks.x86_64-linux.dns-d10
{ config, lib, ... }:
let
  resolvers = import ./_resolvers.nix { inherit lib; };
  inherit (config.flake) nixosConfigurations;
  inherit (config.den) environments;
  hosts = config.den.hosts.x86_64-linux;
  manager = config.den.aspects.core.network.manager;
  uplink = nixosConfigurations.uplink.config;
  guest = parent: name: nixosConfigurations.${parent}.config.microvm.vms.${name}.config.config;

  # Blocky's own listen address, as uplink renders it.
  blocky = lib.head (lib.splitString ":" (lib.head uplink.services.blocky.settings.ports.dns));
  expected = env: [
    blocky
    environments.${env}.networks.default.gatewayIp
  ];

  # Each family's LAN link (test 5): host, environment, its config, link name.
  families = {
    uplink = {
      env = "prod";
      cfg = uplink;
      link = "br0";
    };
    cortex = {
      env = "dev";
      cfg = nixosConfigurations.cortex.config;
      link = "br0";
    };
    axon-01 = {
      env = "prod";
      cfg = nixosConfigurations.axon-01.config;
      link = "enp2s0";
    };
    bitstream = {
      env = "dev";
      cfg = nixosConfigurations.bitstream.config;
      link = "bond0";
    };
    uplink-dev = {
      env = "prod";
      cfg = guest "uplink" "uplink-dev";
      link = "20-lan";
    };
    cortex-cuda = {
      env = "dev";
      cfg = guest "cortex" "cortex-cuda";
      link = "20-lan";
    };
  };
  net = f: f.cfg.systemd.network.networks.${f.link};
  onResolver =
    f:
    (net f).networkConfig.DNS == expected f.env
    && ((net f).networkConfig.DNSOverTLS or false) == false
    && ((net f).ipv6AcceptRAConfig.UseDNS or true) == false
    && f.cfg.services.resolved.settings.Resolve.FallbackDNS == expected f.env;
  leftMagicDns = cfg: lib.elem "--accept-dns=false" cfg.services.tailscale.extraSetFlags;

  blade = nixosConfigurations.blade.config;
  bladeLink = blade.systemd.network.networks.wlp0s20f3.networkConfig;
  noResolvers =
    env:
    env
    // {
      dns = env.dns // {
        resolvers = [ ];
      };
    };

  # test 11: the admitted fleet-wide collection.
  collectsResolvers = host: config.den.policies.collect-dns-resolvers.fn { inherit host; } != [ ];

  clientChecks =
    lib.mapAttrs' (n: f: lib.nameValuePair "${n}OnResolver" (onResolver f)) families
    // lib.mapAttrs' (n: f: lib.nameValuePair "${n}LeftMagicDns" (leftMagicDns f.cfg)) families
    // {
      bladeKeepsUpstreams =
        bladeLink.DNS == environments.dev.networks.default.dnsServers && bladeLink.DNSOverTLS;
      bladeKeepsMagicDns = !(leftMagicDns blade);
      # Controls: the predicate that moves a host fails without resolvers, and for a roaming host.
      unsetKeepsLists = resolvers.resolversFor { } (noResolvers environments.prod) [ ] == null;
      unsetKeepsMagicDns =
        !(resolvers.leavesMagicDns manager (noResolvers environments.dev) hosts.cortex);
      roamingKeepsMagicDns = !(resolvers.leavesMagicDns manager environments.dev hosts.blade);
      staticLeavesMagicDns = resolvers.leavesMagicDns manager environments.dev hosts.cortex;
      # headscale (c): Blocky first, no gateway, then the plain upstreams.
      headscaleRoaming =
        uplink.services.headscale.settings.dns.nameservers.global
        == [ blocky ] ++ resolvers.plainUpstreams environments.prod;
      axonCollectsResolvers = collectsResolvers hosts.axon-01;
    };
  failed = lib.attrNames (lib.filterAttrs (_: ok: !ok) clientChecks);

  # test 7. The fixture spells the literals with ${q} so this file holds none.
  q = ''"'';
  pattern = ''"(8\.8\.8\.8|1\.1\.1\.1|1\.0\.0\.1)"'';
  # The five sites docs/dns-resolver.md §1 lists, two literals each, space-separated.
  removedSites = {
    "coredns.nix" = "1.1.1.1 8.8.8.8";
    "headscale.nix" = "1.1.1.1 1.0.0.1";
    "docker.nix" = "8.8.8.8 1.1.1.1";
    "cortex-cuda.nix" = "1.1.1.1 8.8.8.8";
    "uplink-dev.nix" = "1.1.1.1 8.8.8.8";
  };
  envFiles = ../../../environments;
in
{
  perSystem =
    { pkgs, system, ... }:
    {
      checks = lib.optionalAttrs (system == "x86_64-linux") {
        dns-clients = pkgs.runCommand "dns-clients" { } ''
          failed=${lib.escapeShellArg (lib.concatStringsSep " " failed)}
          if [ -n "$failed" ]; then
            echo "dns-clients: failed: $failed" >&2
            exit 1
          fi
          echo "dns-clients: ${toString (lib.length (lib.attrNames clientChecks))} properties hold"
          touch $out
        '';
        dns-d10 = pkgs.runCommand "dns-d10" { nativeBuildInputs = [ pkgs.ripgrep ]; } ''
          rg() { command rg -n ${lib.escapeShellArg pattern} "$@"; }
          if rg ${../../..}; then
            echo "dns-d10: a hard-coded resolver list remains in modules/den" >&2
            exit 1
          fi
          mkdir sites
          ${lib.concatStrings (
            lib.mapAttrsToList (f: ls: ''
              printf '%s\n' ${lib.escapeShellArgs (map (l: "${q}${l}${q}") (lib.splitString " " ls))} > sites/${f}
            '') removedSites
          )}
          matched=$(rg --no-filename sites | wc -l)
          if [ "$matched" -ne 10 ] || [ "$(command rg -l ${lib.escapeShellArg pattern} sites | wc -l)" -ne 5 ]; then
            echo "dns-d10: control: the pattern matched $matched of the five removed sites' 10 lines" >&2
            exit 1
          fi
          if rg ${envFiles} || ! command rg -q -F '1.1.1.1' ${envFiles}; then
            echo "dns-d10: control: the pattern does not separate the environments' upstreams and acme resolver" >&2
            exit 1
          fi
          echo "dns-d10: no hard-coded list; the pattern matches the five removed sites and spares the environment files"
          touch $out
        '';
      };
    };
}
