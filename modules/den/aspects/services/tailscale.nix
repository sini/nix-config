{
  den,
  lib,
  config,
  ...
}:
{
  den.aspects.services.tailscale = {
    nixos =
      {
        config,
        host,
        ...
      }:
      let
        env = config.den.environments.${host.environment};
        rekeyFile = host.secretPath + "/tailscale-preauthkey.age";
        secretExists = builtins.pathExists rekeyFile;
      in
      lib.mkIf secretExists {
        services.tailscale = {
          enable = true;
          openFirewall = true;
          authKeyFile = config.age.secrets.tailscale-auth-key.path;
          extraUpFlags = [
            "--login-server=https://${env.getDomainFor "headscale"}"
          ];
          extraDaemonFlags = [ "--no-logs-no-support" ];
        };

        networking = {
          nftables.enable = true;
          firewall = {
            checkReversePath = "loose";
            trustedInterfaces = [ config.services.tailscale.interfaceName ];
            allowedUDPPorts = [ config.services.tailscale.port ];
          };
        };

        systemd.services.tailscaled.serviceConfig.Environment = [
          "TS_DEBUG_FIREWALL_MODE=nftables"
        ];
      };

    age-secrets =
      { host, ... }:
      let
        env = config.den.environments.${host.environment};
        rekeyFile = host.secretPath + "/tailscale-preauthkey.age";
      in
      {
        age.secrets.tailscale-auth-key = {
          inherit rekeyFile;
          settings = {
            headscaleHost = builtins.head host.ipv4;
            user = host.hostname;
          };
          generator.script = "tailscale-preauthkey";
        };
      };

    persist = {
      directories = [
        "/var/lib/tailscale"
      ];
    };
  };
}
