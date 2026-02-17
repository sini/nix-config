{ rootPath, ... }:
{
  flake.features.tailscale.nixos =
    {
      config,
      environment,
      # lib,
      # activeFeatures,
      ...
    }:
    # let
    # isMobile = lib.elem "laptop" activeFeatures;
    # in
    {
      # sudo headscale preauthkeys create --user 1 --reusable -e 10y
      age.secrets.tailscale-auth-key = {
        rekeyFile = rootPath + "/.secrets/services/tailscale.age";
      };

      services.tailscale = {
        enable = true;
        openFirewall = true;
        authKeyFile = config.age.secrets.tailscale-auth-key.path;
        extraUpFlags = [ "--login-server=https://hs.${environment.domain}" ];
        # extraUpFlags = lib.mkIf (!isMobile) [
        #   "--advertise-exit-node"
        #   "--exit-node-allow-lan-access"
        # ];
        extraDaemonFlags = [ "--no-logs-no-support" ];
      };

      networking = {
        nftables.enable = true;
        firewall = {
          trustedInterfaces = [ config.services.tailscale.interfaceName ];
          allowedUDPPorts = [ config.services.tailscale.port ];
        };
      };

      systemd.services.tailscaled.serviceConfig.Environment = [
        "TS_DEBUG_FIREWALL_MODE=nftables"
      ];

      environment.persistence."/persist".directories = [
        "/var/lib/tailscale"
      ];
    };
}
