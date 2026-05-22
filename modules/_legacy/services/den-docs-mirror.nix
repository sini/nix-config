{
  features.den-docs-mirror.linux =
    { environment, ... }:
    let
      domain = environment.getDomainFor "den-docs-mirror";
      docRoot = "/var/lib/den-docs";
    in
    {
      services.nginx.virtualHosts = {
        "${domain}" = {
          forceSSL = true;
          useACMEHost = environment.getTopDomainFor "den-docs-mirror";
          locations."/" = {
            root = docRoot;
            extraConfig = ''
              try_files $uri $uri/index.html $uri.html =404;
            '';
          };
        };
      };

      environment.persistence."/persist".directories = [
        {
          directory = docRoot;
          user = "sini";
          mode = "0755";
        }
      ];
    };
}
