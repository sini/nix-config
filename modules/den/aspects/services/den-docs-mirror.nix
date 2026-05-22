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
  den.aspects.services.den-docs-mirror = {
    includes = [ den.aspects.services.nginx ];

    nixos =
      {
        config,
        host,
        ...
      }:
      let
        env = environments.${host.environment};
        domain = env.getDomainFor "den-docs-mirror";
        docRoot = "/var/lib/den-docs";
      in
      {
        services.nginx.virtualHosts = {
          "${domain}" = {
            forceSSL = true;
            useACMEHost = env.domain;
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
