{
  flake.modules.nixos.nginx =
    { config, ... }:
    {
      services.nginx = {
        enable = true;
        recommendedOptimisation = true;
        recommendedProxySettings = true;
        recommendedTlsSettings = true;
        recommendedGzipSettings = true;

        proxyTimeout = "60s";
        clientMaxBodySize = "100m";

        appendHttpConfig = ''
          proxy_headers_hash_max_size 1024;
          proxy_headers_hash_bucket_size 128;
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

      users.groups.acme.members = [ config.services.nginx.user ];
    };
}
