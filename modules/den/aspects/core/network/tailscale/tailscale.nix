# Tailscale mesh — joins the headscale control plane. Auth key is provisioned
# by the secrets concern (secrets.nix); the daemon runs in nftables mode.
{ lib, ... }:
{
  den.aspects.core.network.tailscale = {
    nixos =
      {
        config,
        environment,
        host,
        ...
      }:
      let
        rekeyFile = host.secretPath + "/tailscale-preauthkey.age";
        secretExists = builtins.pathExists rekeyFile;
      in
      lib.mkIf secretExists {
        services.tailscale = {
          enable = true;
          openFirewall = true;
          authKeyFile = config.age.secrets.tailscale-auth-key.path;
          extraUpFlags = [
            "--login-server=https://${environment.getDomainFor "headscale"}"
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

    persist = {
      directories = [
        "/var/lib/tailscale"
      ];
    };
  };
}
