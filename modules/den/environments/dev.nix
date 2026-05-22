# Dev environment entity definition.
{ self, ... }:
{
  den.environments.dev = {
    id = 2;
    domain = "json64.dev";
    system-access-groups = [ "system-access" ];

    certificates = {
      domains = {
        "json64.dev" = {
          issuer = "json64-dev";
        };
      };
      issuers = {
        "json64-dev" = {
          ageKeyFile = "${self}/.secrets/env/dev/cloudflare-api-key.age";
        };
      };
    };

    services = {
      argocd.domain = "argocd.dev.json64.dev";
      hubble-ui.domain = "hubble.dev.json64.dev";
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

    networks = {
      default = {
        cidr = "10.9.0.0/16";
        ipv6_cidr = "fd64:1:1::/64";
        description = "Default network for infrastructure hosts";
        gatewayIp = "10.9.0.1";
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
      environment = "dev";
      owner = "json64";
    };

    delegation = {
      metricsTo = "prod";
      authTo = "prod";
      logsTo = "prod";
    };
  };
}
