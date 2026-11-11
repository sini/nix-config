# The admin panel's pure check (docs/dns-resolver.md §2.6, test 15), over
# uplink's evaluated config. Each property has a control that must fail it:
#   loopback   the container publishes no port, shares the host network and
#              binds 127.0.0.1, its port is not opened, and oauth2-proxy listens
#              on loopback; controls: HOSTNAME 0.0.0.0, a published port
#   gated      the vhost runs auth_request, no location turns it off, and the
#              auth subrequest carries the group gate; controls: homepage's
#              vhost (authenticated, ungated), the vhost without auth_request,
#              a location with auth_request off
#   claim      the gate is <group>@<kanidm domain>, the SPN form kanidm's groups
#              claim carries, for a provisioned group whose oauth2-proxy scope
#              map grants `groups`, and oauth2-proxy requests that scope;
#              controls: the bare name, the idm.<domain> form, no groups scope
#   api        no vhost location proxies to Blocky's HTTP port, and the panel's
#              only server is Blocky on loopback; control: a vhost that does
#   nix build .#checks.x86_64-linux.blocky-ui
{ config, lib, ... }:
let
  nixos = config.flake.nixosConfigurations.uplink.config;
  container = nixos.virtualisation.oci-containers.containers.blocky-ui;
  vhosts = nixos.services.nginx.virtualHosts;
  proxy = nixos.services.oauth2-proxy;
  kanidm = nixos.services.kanidm;
  domain = config.den.environments.prod.getDomainFor "dns";
  blockyPort = toString (
    config.den.hosts.x86_64-linux.uplink.settings.services.networking.blocky.httpPort or 4000
  );
  gates = proxy.nginx.virtualHosts.${domain}.allowed_groups;
  authPath = "= /oauth2/auth";

  loopbackOnly =
    c:
    c.ports == [ ]
    && lib.elem "--network=host" c.extraOptions
    && c.environment.HOSTNAME == "127.0.0.1"
    && !(lib.elem (lib.toInt c.environment.PORT) nixos.networking.firewall.allowedTCPPorts);

  gated =
    gate: v:
    lib.hasInfix "auth_request /oauth2/auth;" v.extraConfig
    && lib.all (l: !(lib.hasInfix "auth_request off" l.extraConfig)) (
      lib.attrValues (
        removeAttrs v.locations [
          authPath
          "@redirectToAuth2ProxyLogin"
        ]
      )
    )
    &&
      (v.locations.${authPath}.proxyPass or null)
      == "${proxy.nginx.proxy}/oauth2/auth?allowed_groups=${lib.escapeURL gate}";

  claimForm =
    scope: gate:
    let
      parts = lib.splitString "@" gate;
      group = lib.head parts;
    in
    lib.length parts == 2
    && lib.last parts == kanidm.server.settings.domain
    && kanidm.provision.groups ? ${group}
    && lib.elem "groups" (kanidm.provision.systems.oauth2.oauth2-proxy.scopeMaps.${group} or [ ])
    && lib.elem "groups" (lib.splitString " " scope)
    && proxy.extraConfig.oidc-groups-claim == "groups";

  noApiProxy =
    vs:
    lib.all (
      v:
      lib.all (l: !(lib.hasSuffix ":${blockyPort}" (lib.removeSuffix "/" (toString l.proxyPass)))) (
        lib.attrValues v.locations
      )
    ) (lib.attrValues vs);

  gate = lib.head gates;
  vhost = vhosts.${domain};
  uiConfig = lib.head (lib.splitString ":" (lib.head container.volumes));

  checks = {
    loopback = loopbackOnly container && lib.hasPrefix "http://127.0.0.1:" proxy.httpAddress;
    loopbackWildcardFails =
      !(loopbackOnly (
        container
        // {
          environment = container.environment // {
            HOSTNAME = "0.0.0.0";
          };
        }
      ));
    loopbackPublishedFails =
      !(loopbackOnly (
        container
        // {
          ports = [ "3010:3010" ];
          extraOptions = [ ];
        }
      ));
    oneGate = lib.length gates == 1;
    gated = gated gate vhost;
    gatedHomepageFails = !(gated gate vhosts.${config.den.environments.prod.getDomainFor "homepage"});
    gatedNoAuthRequestFails = !(gated gate (vhost // { extraConfig = ""; }));
    gatedLocationOffFails =
      !(gated gate (lib.recursiveUpdate vhost { locations."/".extraConfig = "auth_request off;"; }));
    claim = claimForm proxy.scope gate;
    claimBareNameFails = !(claimForm proxy.scope (lib.head (lib.splitString "@" gate)));
    claimIdmHostFails =
      !(claimForm proxy.scope "${lib.head (lib.splitString "@" gate)}@${config.den.environments.prod.getDomainFor "kanidm"}");
    claimNoGroupsScopeFails = !(claimForm "openid email profile" gate);
    api = noApiProxy vhosts;
    apiProxiedFails =
      !(noApiProxy (vhosts // { control.locations."/".proxyPass = "http://127.0.0.1:${blockyPort}"; }));
    blockyOnLoopback = lib.elem "127.0.0.1:${blockyPort}" nixos.services.blocky.settings.ports.http;
  };
  failed = lib.attrNames (lib.filterAttrs (_: ok: !ok) checks);
in
{
  perSystem =
    { pkgs, system, ... }:
    {
      checks = lib.optionalAttrs (system == "x86_64-linux") {
        blocky-ui = pkgs.runCommand "blocky-ui" { } ''
          failed=${lib.escapeShellArg (lib.concatStringsSep " " failed)}
          if [ -n "$failed" ]; then
            echo "blocky-ui: failed: $failed" >&2
            exit 1
          fi
          # The panel's servers: one url, Blocky on loopback; control: the same file at the LAN address fails.
          onLoopback() { [ "$(grep -c 'url:' "$1")" = 1 ] && grep -qE '^ +url: "?http://127\.0\.0\.1:${blockyPort}"?$' "$1"; }
          onLoopback ${uiConfig} || { echo "blocky-ui: the panel's server is not Blocky on loopback" >&2; exit 1; }
          sed 's/127\.0\.0\.1/192.0.2.1/' ${uiConfig} > lan.yml
          if onLoopback lan.yml; then echo "blocky-ui: control: a LAN server url passes" >&2; exit 1; fi
          echo "blocky-ui: ${toString (lib.length (lib.attrNames checks))} properties hold; the panel's one server is Blocky on loopback"
          touch $out
        '';
      };
    };
}
