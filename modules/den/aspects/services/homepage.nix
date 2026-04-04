{ den, ... }:
{
  den.aspects.homepage = den.lib.perHost (
    { host }:
    let
      inherit (host) environment;
      domain = environment.getDomainFor "homepage";
    in
    {
      nixos = {
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
              useACMEHost = environment.getTopDomainFor "homepage";
              locations."/" = {
                proxyPass = "http://127.0.0.1:8082";
                proxyWebsockets = true;
              };
            };
          };
        };
      };
    }
  );
}
