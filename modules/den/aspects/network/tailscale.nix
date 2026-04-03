{ den, lib, ... }:
{
  den.aspects.tailscale = {
    includes = lib.attrValues den.aspects.tailscale._;

    _ = {
      config = den.lib.perHost {
        nixos =
          { config, ... }:
          {
            # Simplified tailscale config - secrets/auth deferred to environment context migration
            services.tailscale = {
              enable = true;
              openFirewall = true;
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

        # Darwin activation script deferred - needs secrets integration (Task 3)
      };

      impermanence = den.lib.perHost {
        nixos = {
          environment.persistence."/persist".directories = [
            "/var/lib/tailscale"
          ];
        };
      };
    };
  };
}
