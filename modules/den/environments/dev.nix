{ rootPath, ... }:
{
  den.environments.dev = {
    id = 2;
    domain = "json64.dev";
    secretPath = rootPath + "/.secrets/env/dev";
    timezone = "America/Los_Angeles";

    location = {
      country = "US";
      region = "us-west";
    };

    tags = {
      environment = "dev";
      owner = "json64";
    };

    networks.default = {
      cidr = "10.9.0.0/16";
      ipv6_cidr = "fd64:1:1::/64";
      description = "Default network for infrastructure hosts";
      gatewayIp = "10.9.0.1";
      gatewayIpV6 = "fe80::962a:6fff:fef2:cf4d";
      dnsServers = [
        # Cloudflare
        "1.1.1.1"
        "2606:4700:4700::1111"
        "1.0.0.1"
        "2606:4700:4700::1001"

        # Public Nat64 -- https://nat64.net
        "2a01:4f8:c2c:123f::1"
        "2a00:1098:2b::1"
      ];
      wireless = {
        ssid = "The Arcade";
        pskRef = "ext:psk_arcade";
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

    certificates = {
      issuers = {
        "json64-dev" = {
          ageKeyFile = rootPath + "/.secrets/env/dev/cloudflare-api-key.age";
        };
      };
      domains = {
        "json64.dev" = {
          issuer = "json64-dev";
        };
      };
    };

    # Service domain mappings
    services = {
      # Kubernetes services
      argocd.domain = "argocd.dev.json64.dev";
      hubble-ui.domain = "hubble.dev.json64.dev";

      # Prod references
      attic = {
        delegateTo = "prod";
        domain = "attic.json64.dev";
      };
      headscale = {
        delegateTo = "prod";
        domain = "hs.json64.dev";
      };
      kanidm = {
        delegateTo = "prod";
        domain = "idm.json64.dev";
      };
    };

    wirelessSecretsFile = rootPath + "/.secrets/env/dev/wpa_supplicant_psks.age";

    delegation = {
      metricsTo = "prod";
      authTo = "prod";
      logsTo = "prod";
    };

    system-access-groups = [ "system-access" ];
  };
}
