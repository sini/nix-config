{ den, lib, ... }:
{
  den.aspects.nginx = {
    includes = lib.attrValues den.aspects.nginx._;

    _ = {
      config = den.lib.perHost (
        { host }:
        {
          nixos =
            { config, ... }:
            let
              inherit (host) environment;

              # Extract top-level domain from a full domain name
              extractTopDomain =
                domain:
                let
                  parts = lib.splitString "." domain;
                  topDomain = lib.reverseList (lib.take 2 (lib.reverseList parts));
                in
                lib.concatStringsSep "." topDomain;

              # Get all top-level domains from configured virtual hosts
              topDomains =
                builtins.attrNames config.services.nginx.virtualHosts
                # Exclude localhost and hosts starting with _
                |> lib.filter (host': host' != "localhost" && !(lib.hasPrefix "_" host'))
                # Map to top-level domains
                |> map extractTopDomain
                # Get unique domains
                |> lib.unique;

              # Look up issuer for each domain
              domainIssuerMap = lib.listToAttrs (
                map (domain: {
                  name = domain;
                  value =
                    let
                      domainConfig = (environment.certificates.domains or { }).${domain} or null;
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
                    useACMEHost = environment.domain;
                    default = true;
                    locations."/" = {
                      return = "404";
                    };
                  };
                };

                # Enable nginx status for nginx exporter
                statusPage = true;
              };

              services.prometheus.exporters = {
                nginx = {
                  enable = true;
                  port = 9113;
                  listenAddress = "127.0.0.1";
                };
              };

              users.groups.acme.members = [ config.services.nginx.user ];
            };
        }
      );

      firewall = den.lib.perHost {
        firewall.allowedTCPPorts = [
          80
          443
        ];
      };
    };
  };
}
