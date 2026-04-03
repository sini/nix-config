{ den, lib, ... }:
{
  den.aspects.tailscale = {
    includes = lib.attrValues den.aspects.tailscale._;

    _ = {
      config = den.lib.perHost (
        { host }:
        let
          tsCfg = host.settings.tailscale;
        in
        {
          nixos =
            { config, ... }:
            {
              services.tailscale = {
                enable = true;
                inherit (tsCfg) openFirewall;
                inherit (tsCfg) extraUpFlags;
                inherit (tsCfg) extraDaemonFlags;
              };

              networking = {
                nftables.enable = tsCfg.useNftables;
                firewall = {
                  checkReversePath = "loose";
                  trustedInterfaces = [ config.services.tailscale.interfaceName ];
                  allowedUDPPorts = [ config.services.tailscale.port ];
                };
              };

              systemd.services.tailscaled.serviceConfig.Environment = lib.mkIf tsCfg.useNftables [
                "TS_DEBUG_FIREWALL_MODE=nftables"
              ];
            };
        }
      );

      impermanence = den.lib.perHost {
        persist.directories = [
          "/var/lib/tailscale"
        ];
      };
    };
  };
}
