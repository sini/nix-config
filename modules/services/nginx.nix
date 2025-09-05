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

        virtualHosts._ = {
          forceSSL = true;
          useACMEHost = config.networking.domain;
          default = true;
          locations."/" = {
            return = "404";
          };
        };
      };

      users.groups.acme.members = [ config.services.nginx.user ];
    };
}
