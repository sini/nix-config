# Static status dashboard for the gen ecosystem (gen-status.json64.dev).
{ den, ... }:
let
  serviceDomains = [ "gen-status" ];
in
{
  den.aspects.services.web.gen-status = {
    includes = [ den.aspects.services.networking.nginx ];

    nixos =
      {
        environment,
        host,
        ...
      }:
      let
        domain = environment.getDomainFor "gen-status";
        docRoot = "/var/lib/gen-status";
      in
      {
        services.nginx.virtualHosts = {
          "${domain}" = {
            forceSSL = true;
            useACMEHost = environment.domain;
            locations."/" = {
              root = docRoot;
              extraConfig = ''
                try_files $uri $uri/index.html $uri.html =404;
                etag on;
              '';
            };
            locations."/data/" = {
              root = docRoot;
              extraConfig = ''
                add_header Cache-Control "public, max-age=60, must-revalidate";
                gzip_static on;
              '';
            };
          };
        };
      };

    service-domains = serviceDomains;
    served-domains = { environment, host, ... }: environment.servedDomains host serviceDomains;

    persist = {
      directories = [
        {
          directory = "/var/lib/gen-status";
          user = "sini";
          mode = "0755";
        }
      ];
    };
  };
}
