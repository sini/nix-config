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
  den.aspects.services.forgejo = {
    includes = [ den.aspects.services.nginx ];

    nixos =
      {
        config,
        host,
        ...
      }:
      let
        env = environments.${host.environment};
        domain = env.getDomainFor "forgejo";
      in
      {
        users.groups.git = { };
        users.users.git = {
          isSystemUser = true;
          useDefaultShell = true;
          group = "git";
          home = config.services.forgejo.stateDir;
        };

        services.openssh = {
          authorizedKeysFiles = lib.mkForce [
            "${config.services.forgejo.stateDir}/.ssh/authorized_keys"
          ];
          settings.AcceptEnv = [ "GIT_PROTOCOL" ];
        };

        services.nginx.virtualHosts."${domain}" = {
          forceSSL = true;
          useACMEHost = env.domain;
          locations."/" = {
            proxyPass = "http://127.0.0.1:3000";
            proxyWebsockets = true;
          };
        };
      };

    firewall = {
      networking.firewall.allowedTCPPorts = [ 7654 ];
    };

    service-domains = [ "forgejo" ];

    persist = {
      directories = [
        {
          directory = "/var/lib/forgejo";
          user = "git";
          group = "git";
          mode = "0700";
        }
      ];
    };
  };
}
