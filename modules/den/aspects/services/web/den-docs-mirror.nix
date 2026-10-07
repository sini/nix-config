{ den, ... }:
let
  serviceDomains = [ "den-docs-mirror" ];
in
{
  den.aspects.services.web.den-docs-mirror = {
    includes = [ den.aspects.services.networking.nginx ];

    nixos =
      {
        environment,
        host,
        ...
      }:
      let
        domain = environment.getDomainFor "den-docs-mirror";
        docRoot = "/var/lib/den-docs";
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
          directory = "/var/lib/den-docs";
          user = "sini";
          mode = "0755";
        }
      ];
    };
  };
}
