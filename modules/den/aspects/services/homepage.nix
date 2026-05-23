{
  den,
  config,
  ...
}:
let
  environments = config.den.environments;
in
{
  den.aspects.services.homepage = {
    includes = [
      den.aspects.services.nginx
      den.aspects.services.oauth2-proxy
    ];

    nixos =
      {
        host,
        ...
      }:
      let
        env = environments.${host.environment};
        domain = env.getDomainFor "homepage";
      in
      {
        services = {
          homepage-dashboard = {
            enable = true;
            listenPort = 8082;

            allowedHosts = "*";

            services = [
              {
                "Self-hosted services" = [
                  {
                    "Blog" = {
                      description = "Blog";
                      href = "http://google.com/";
                      siteMonitor = "http://google.com/";
                      icon = "sonarr.png";
                    };
                  }
                ];
              }
              {
                "My Second Group" = [
                  {
                    "My Second Service" = {
                      description = "Homepage is the best";
                      href = "http://localhost/";
                    };
                  }
                ];
              }
            ];

            settings = {
              title = "hello world";
            };

            bookmarks = [
              {
                Developer = [
                  {
                    Github = [
                      {
                        abbr = "GH";
                        href = "https://github.com/";
                      }
                    ];
                  }
                ];
              }
              {
                Entertainment = [
                  {
                    YouTube = [
                      {
                        abbr = "YT";
                        href = "https://youtube.com/";
                      }
                    ];
                  }
                ];
              }
            ];
          };

          oauth2-proxy.nginx.virtualHosts = {
            "${domain}" = { };
          };

          nginx.virtualHosts = {
            "${domain}" = {
              forceSSL = true;
              useACMEHost = env.domain;
              locations."/" = {
                proxyPass = "http://127.0.0.1:8082";
                proxyWebsockets = true;
              };
            };
          };
        };
      };

    service-domains = [ "homepage" ];
  };
}
