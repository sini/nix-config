# Prod environment entity definition.
{ self, lib, ... }:
let
  certificateDomains = {
    "json64.dev" = {
      issuer = "json64-dev";
      # Apex listener: serves json64.dev/.well-known/matrix/* (Matrix
      # delegation for server_name json64.dev; see communication/matrix/synapse.nix).
      apex = true;
    };
    "s3.json64.dev" = {
      issuer = "json64-dev";
      # Distinct stem: without it resourceForDomain "s3.json64.dev" = json64-dev,
      # colliding with the json64.dev wildcard. Enables the *.s3.json64.dev
      # listener + s3-json64-dev-wildcard-tls cert (T1 resourceName extension).
      resourceName = "s3-json64-dev";
    };
    # tuwunel companion homeserver (matrix.gen.wtf); the apex stays GitHub Pages.
    "gen.wtf" = {
      issuer = "global";
    };
    "gen-framework.com" = {
      issuer = "global";
      apex = true; # landing page (garage/sites.nix)
    };
    "qvr-framework.com" = {
      issuer = "global";
      apex = true; # landing page (garage/sites.nix)
    };
    # quiver: candidate project domains (Cloudflare zones, `global` DNS-01).
    "getqvr.com" = {
      issuer = "global";
      apex = true; # landing page (garage/sites.nix)
    };
    "quiver-labs.com" = {
      issuer = "global";
      apex = true; # landing page (garage/sites.nix)
    };
    "qvrlab.com" = {
      issuer = "global";
      apex = true; # landing page (garage/sites.nix)
    };
    "qvr.run" = {
      issuer = "global";
      apex = true; # landing page (garage/sites.nix)
    };
    "qvr.sh" = {
      issuer = "global";
      apex = true; # landing page (garage/sites.nix)
    };
    "json64.com" = {
      issuer = "global";
    };
    "json64.net" = {
      issuer = "global";
    };
    "sinistar.io" = {
      issuer = "global";
    };
    "sinistar.org" = {
      issuer = "global";
    };
    "zeroday.pub" = {
      issuer = "global";
    };
    "zeroday.run" = {
      issuer = "global";
    };
  };
in
{
  den.environments.prod = {
    id = 1;
    domain = "json64.dev";
    system-access-groups = [ "system-access" ];

    certificates = {
      domains = certificateDomains;
      issuers = {
        "json64-dev" = {
          ageKeyFile = "${self}/.secrets/env/prod/cloudflare-api-key.age";
        };
        "global" = {
          ageKeyFile = "${self}/.secrets/env/prod/cloudflare-api-key.age";
        };
      };
    };

    # Public DNS: modules/flake-parts/terranix, infra/dns/README.md.
    dns = {
      publicIPv4 = "157.131.140.225";
      # Matrix federation and S3 clients do not survive the Cloudflare proxy.
      unproxied = [
        "matrix.json64.dev"
        "matrix.gen.wtf"
        "s3.json64.dev"
        "*.s3.json64.dev"
      ];
      # As live: hs and jellyfin are grey CNAMEs to the apex; *.s3 is S3 vhost style.
      records = {
        "hs.json64.dev" = {
          type = "CNAME";
          content = "json64.dev";
          proxied = false;
        };
        "jellyfin.json64.dev" = {
          type = "CNAME";
          content = "json64.dev";
          proxied = false;
        };
        "*.s3.json64.dev" = { };
        # Shared public IP for ssh and some tailscale users (grey-cloud: not HTTP).
        "vpn.json64.dev".proxied = false;
        # GitHub Pages verified domain for gen.wtf (account sini).
        "_github-pages-challenge-sini.gen.wtf" = {
          type = "TXT";
          content = "976e8aa7ced3167338668254c4f312";
          proxied = false;
        };
      };
      # The apex (landing) zones, json64.dev among them, plus gen.wtf: its apex
      # stays GitHub Pages, but matrix.gen.wtf is ours.
      managedZones = builtins.attrNames (lib.filterAttrs (_: d: d.apex or false) certificateDomains) ++ [
        "gen.wtf"
      ];
    };

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

    networks = {
      default = {
        cidr = "10.10.0.0/16";
        ipv6_cidr = "fe80::/64";
        description = "Default network for infrastructure hosts";
        gatewayIp = "10.10.0.1";
        gatewayIpV6 = "fe80::962a:6fff:fef2:cf4d";
        dnsServers = [
          "1.1.1.1"
          "2606:4700:4700::1111"
          "1.0.0.1"
          "2606:4700:4700::1001"
          "2a01:4f8:c2c:123f::1"
          "2a00:1098:2b::1"
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
