{
  # We are having issues with the nixpkg socket... so lets stash our own service for now with fixed users.
  flake.features.homepage.nixos =
    { environment, ... }:
    {

      services.homepage-dashboard = {
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
          # startUrl: https://custom.url
          title = "hello world";
        };

        # listenPort=
        # oopenFirewall
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

      services.oauth2-proxy.nginx.virtualHosts = {
        "homepage.${environment.domain}" = { };
      };

      services.nginx.virtualHosts = {
        "homepage.${environment.domain}" = {
          forceSSL = true;
          useACMEHost = environment.domain;
          locations."/" = {
            proxyPass = "http://127.0.0.1:8082";
            proxyWebsockets = true;
          };
        };
      };

      # environment.persistence."/persist".directories = [
      #   {
      #     directory = "/var/lib/private/tang";
      #     user = "nobody";
      #     group = "nogroup";
      #     mode = "0700";
      #   }
      # ];
    };
}
