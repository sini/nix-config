{ den, ... }:
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

    service-domains = [ "den-docs-mirror" ];

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
