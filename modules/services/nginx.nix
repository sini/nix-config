{
  flake.features.nginx.nixos =
    { config, ... }:
    {
      security.acme.certs.${config.networking.domain} = {
        extraDomainNames = [ "*.${config.networking.domain}" ];
        group = config.services.nginx.group;
      };

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
            useACMEHost = config.networking.domain;
            default = true;
            locations."/" = {
              return = "404";
            };
          };
        };
      };

      networking.firewall.allowedTCPPorts = [
        80
        443
      ];

      users.groups.acme.members = [ config.services.nginx.user ];
    };
}
