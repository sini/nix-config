{ rootPath, ... }:
{
  flake.environments.prod = {
    id = 1;
    domain = "json64.dev";

    # Certificate management configuration
    certificates = {
      domains = {
        "json64.dev" = {
          issuer = "json64-dev";
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
      issuers = {
        "json64-dev" = {
          ageKeyFile = rootPath + "/.secrets/env/prod/cloudflare-api-key.age";
          sopsFile = rootPath + "/.secrets/env/prod/k8s-secrets.enc.yaml";
          secretKey = "cloudflare-api-token";
        };
        "global" = {
          ageKeyFile = rootPath + "/.secrets/env/prod/cloudflare-api-key.age";
          sopsFile = rootPath + "/.secrets/env/prod/k8s-secrets.enc.yaml";
          secretKey = "cloudflare-global-api-token";
        };
      };
    };

    # Service domain mappings
    services = {
      # Kubernetes services
      argocd.domain = "argocd.zeroday.run";
      hubble-ui.domain = "hubble.zeroday.run";

      # NixOS services
      grafana.domain = "grafana.json64.dev";
      headscale.domain = "hs.json64.dev";
      homepage.domain = "homepage.json64.dev";
      jellyfin.domain = "jellyfin.json64.dev";
      kanidm.domain = "idm.json64.dev";
      loki.domain = "loki.json64.dev";
      minio.domain = "minio.json64.dev";
      minio-console.domain = "minio-console.json64.dev";
      oauth2-proxy.domain = "oauth2-proxy.json64.dev";
      open-webui.domain = "open-webui.json64.dev";
      prometheus.domain = "prometheus.json64.dev";
      vault.domain = "vault.json64.dev";
    };

    networks = {
      default = {
        cidr = "10.10.0.0/16";
        ipv6_cidr = "fe80::/64";
        description = "Default network for infrastructure hosts";
        gatewayIp = "10.10.0.1";
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
        assignments = {
          kube-apiserver-vip = "10.10.10.100";
        };
      };
      kubernetes-pods = {
        cidr = "172.20.0.0/16";
        ipv6_cidr = "fdfd:cafe:00:0001::/96";
        description = "Kubernetes pod network";
      };
      kubernetes-services = {
        cidr = "172.21.0.0/16";
        ipv6_cidr = "fdfd:cafe:00:8001::/112";
        description = "Kubernetes service network";
        assignments = {
          coredns = "172.21.0.10";
        };
      };
      kubernetes-loadbalancers = {
        cidr = "10.11.0.0/16";
        description = "LoadBalancer service IP range";
        assignments = {
          cilium-ingress-controller = "10.11.0.2";
          default-gateway = "10.11.0.1";
        };
      };
    };

    # IPv6 ULA configuration
    ipv6 = {
      ula_prefix = "fd64::/48";
      management_prefix = "fd64:0:1::/64";
      kubernetes_prefix = "fd64:0:2::/64";
      services_prefix = "fd64:0:3::/64";
      # External ISP prefix for NPTv6 translation (placeholder)
      external_prefix = "2001:5a8:608c:4a00::/64";
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

    users = {
      sini = { };
      shuo = { };
      will = { };
      media = { };
    };

    monitoring = {
      scanEnvironments = [
        "prod"
        "dev"
      ];
    };
  };
}
