# Prod environment entity definition.
{ self, ... }:
{
  den.environments.prod = {
    id = 1;
    domain = "json64.dev";
    system-access-groups = [ "system-access" ];

    # Domains (their certificates and public records): modules/den/domains.
    certificates.issuers = {
      "json64-dev" = {
        ageKeyFile = "${self}/.secrets/env/prod/cloudflare-api-key.age";
      };
      "global" = {
        ageKeyFile = "${self}/.secrets/env/prod/cloudflare-api-key.age";
      };
    };

    # Public DNS: modules/flake-parts/terranix, infra/dns/README.md.
    dns.publicIPv4 = "157.131.140.225";

    services = {
      argocd.domain = "argocd.zeroday.run";
      hubble-ui.domain = "hubble.zeroday.run";
      longhorn.domain = "longhorn.zeroday.run";
      attic.domain = "attic.json64.dev";
      forgejo.domain = "git.json64.dev";
      garage-s3.domain = "s3.json64.dev";
      garage-ui.domain = "garage.json64.dev";
      grafana.domain = "grafana.json64.dev";
      headscale.domain = "hs.json64.dev";
      homepage.domain = "homepage.json64.dev";
      # k8s media utility dashboard (gethomepage). Distinct from the uplink
      # homepage above (homepage.json64.dev): see kanidm.nix mediaClientDefs.dash.
      dash.domain = "dash.json64.dev";
      jellyfin.domain = "jellyfin.json64.dev";
      kanidm.domain = "idm.json64.dev";
      loki.domain = "loki.json64.dev";
      minio.domain = "minio.json64.dev";
      minio-console.domain = "minio-console.json64.dev";
      oauth2-proxy.domain = "oauth2-proxy.json64.dev";
      open-webui.domain = "open-webui.json64.dev";
      prometheus.domain = "prometheus.json64.dev";
      # qBittorrent routes on torrent.* (not the default qbittorrent.*); the
      # media helper reads this via getDomainFor "qbittorrent".
      qbittorrent.domain = "torrent.json64.dev";
      registry.domain = "registry.json64.dev";
      # SABnzbd routes on nzb.* (not the default sabnzbd.*); the media helper
      # reads this via getDomainFor "sabnzbd".
      sabnzbd.domain = "nzb.json64.dev";
      vault.domain = "vault.json64.dev";
      den-docs-mirror.domain = "den.json64.dev";
      # Companion homeserver (kubernetes/.../matrix/tuwunel.nix).
      tuwunel.domain = "matrix.gen.wtf";
    };

    # The UniFi gateway: modules/flake-parts/terranix/unifi.nix, infra/unifi/README.md.
    # Its BGP config is rendered from the environment's bgp-peers, its port
    # forwards from the environment's port-forwards.
    # The gateway has two WAN ports; only wan is connected today. Forwards that
    # set allWans keep accepting on wan2 if a second uplink is ever attached.
    unifi.wans = [
      "wan"
      "wan2"
    ];
    unifi.bgp = {
      description = "edge-prod";
      uploadFileName = "unifi-frr-bgp-prod.conf";
    };

    networks = {
      default = {
        cidr = "10.10.0.0/16";
        ipv6_cidr = "fe80::/64";
        description = "Default network for infrastructure hosts";
        gatewayIp = "10.10.0.1";
        gatewayAsn = 65999;
        gatewayIpV6 = "fe80::962a:6fff:fef2:cf4d";
        # Validating DNS-over-TLS resolvers from two operators, in resolved's
        # "address#tls-name" form (the name authenticates the TLS certificate).
        # No DNS64 resolvers: they synthesise AAAA records that route IPv4-only
        # destinations through a third party's NAT64 gateway.
        dnsServers = [
          "1.1.1.1#cloudflare-dns.com"
          "2606:4700:4700::1111#cloudflare-dns.com"
          "1.0.0.1#cloudflare-dns.com"
          "2606:4700:4700::1001#cloudflare-dns.com"
          "9.9.9.9#dns.quad9.net"
          "2620:fe::fe#dns.quad9.net"
        ];
        wireless = {
          ssid = "The Arcade";
          pskRef = "ext:psk_arcade";
        };
      };
    };

    email = {
      domain = "json64.dev";
      adminEmail = "jason@json64.dev";
    };

    acme = {
      server = "https://acme-v02.api.letsencrypt.org/directory";
      dnsProvider = "cloudflare";
      dnsResolver = "1.1.1.1:53";
    };

    timezone = "America/Los_Angeles";

    location = {
      country = "US";
      region = "us-west";
    };

    tags = {
      environment = "prod";
      owner = "json64";
    };

    monitoring = {
      scanEnvironments = [
        "prod"
        "dev"
      ];
    };
  };
}
