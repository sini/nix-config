{
  den,
  lib,
  config,
  ...
}:
let
  environments = config.den.environments;
in
{
  den.aspects.services.nginx = {
    includes = [ den.aspects.services.acme ];

    nixos =
      { config, host, ... }:
      let
        env = environments.${host.environment};

        # Extract top-level domain from a full domain name
        extractTopDomain =
          domain:
          let
            parts = lib.splitString "." domain;
            topDomain = lib.reverseList (lib.take 2 (lib.reverseList parts));
          in
          lib.concatStringsSep "." topDomain;

        # Get all unique top-level domains from configured virtual hosts
        topDomains =
          builtins.attrNames config.services.nginx.virtualHosts
          |> lib.filter (h: h != "localhost" && !(lib.hasPrefix "_" h))
          |> map extractTopDomain
          |> lib.unique;

        # Look up issuer for each domain via environment certificates config
        domainIssuerMap = lib.listToAttrs (
          map (domain: {
            name = domain;
            value =
              let
                domainConfig = (env.certificates.domains or { }).${domain} or null;
              in
              if domainConfig != null then domainConfig.issuer else null;
          }) topDomains
        );

        # Generate ACME cert configurations for each top-level domain
        acmeCerts = lib.listToAttrs (
          map (
            domain:
            let
              issuerName = domainIssuerMap.${domain};
            in
            {
              name = domain;
              value = {
                extraDomainNames = [ "*.${domain}" ];
                group = config.services.nginx.group;
                credentialFiles = lib.mkIf (issuerName != null) {
                  CLOUDFLARE_DNS_API_TOKEN_FILE = config.age.secrets."${issuerName}-cloudflare-api-key".path;
                };
              };
            }
          ) topDomains
        );
      in
      {
        security.acme.certs = acmeCerts;

        services.nginx = {
          enable = true;
          recommendedOptimisation = true;
          recommendedProxySettings = true;
          recommendedTlsSettings = true;
          recommendedGzipSettings = true;

          proxyTimeout = "60s";
          clientMaxBodySize = "100m";

          appendConfig = ''
            # Log to journald instead of files
            error_log syslog:server=unix:/dev/log,facility=local1,tag=nginx_error;
          '';

          appendHttpConfig = ''
            proxy_headers_hash_max_size 1024;
            proxy_headers_hash_bucket_size 128;

            # Access logs to journald
            access_log syslog:server=unix:/dev/log,facility=local0,tag=nginx_access;
          '';

          virtualHosts = {
            _ = {
              forceSSL = true;
              useACMEHost = env.domain;
              default = true;
              locations."/" = {
                return = "404";
              };
            };
          };

          # Enable nginx status for prometheus exporter
          statusPage = true;
        };

        services.prometheus.exporters.nginx = {
          enable = true;
          port = 9113;
          listenAddress = "127.0.0.1";
        };

        users.groups.acme.members = [ config.services.nginx.user ];
      };

    firewall = {
      networking.firewall.allowedTCPPorts = [
        80
        443
      ];
    };

    prometheus-targets =
      { host, ... }:
      {
        hostname = host.name;
        ip = builtins.head host.ipv4;
        inherit (host) environment;
        exporters = [
          {
            job = "nginx";
            port = 9113;
          }
        ];
      };

    persist = {
      directories = [
        {
          directory = "/var/lib/acme";
          user = "acme";
          group = "acme";
          mode = "0755";
        }
      ];
    };
  };
}
