{
  features.tailscale = {
    system =
      {
        environment,
        ...
      }:
      {
        # sudo headscale preauthkeys create --user 1 --reusable -e 10y
        age.secrets.tailscale-auth-key = {
          rekeyFile = environment.secretPath + "/tailscale.age";
        };

        services.tailscale.enable = true;
      };

    darwin =
      {
        config,
        environment,
        host,
        pkgs,
        ...
      }:
      let
        authKeyPath = config.age.secrets.tailscale-auth-key.path;
      in
      {
        system.activationScripts.postActivation.text = ''
          # Tailscale auto-authentication
          if [ -f "${authKeyPath}" ]; then
            echo "Configuring Tailscale..."

            # Wait for tailscaled to be ready (max 10 seconds)
            for _ in $(seq 1 10); do
              if /run/current-system/sw/bin/tailscale status &>/dev/null; then
                break
              fi
              sleep 1
            done

            # Check current state
            current_status=$(/run/current-system/sw/bin/tailscale status --json 2>/dev/null | ${pkgs.jq}/bin/jq -r '.BackendState // "Unknown"' || echo "Unknown")

            if [ "$current_status" = "Running" ]; then
              echo "Tailscale already connected"
            else
              echo "Authenticating Tailscale with hostname ${host.hostname}..."
              # Use --reset to clear any conflicting non-default settings
              /run/current-system/sw/bin/tailscale up \
                --login-server=https://${environment.getDomainFor "headscale"} \
                --auth-key="$(cat ${authKeyPath})" \
                --hostname="${host.hostname}" \
                --no-logs-no-support \
                --reset \
                || echo "Tailscale auth failed (may need manual login)"
            fi
          else
            echo "Warning: Tailscale auth key not found at ${authKeyPath}"
            echo "Run: sops secrets/darwin.yaml to add tailscale-auth"
          fi
        '';

      };

    linux =
      {
        config,
        environment,
        ...
      }:
      {

        services.tailscale = {
          openFirewall = true;
          authKeyFile = config.age.secrets.tailscale-auth-key.path;
          extraUpFlags = [ "--login-server=https://${environment.getDomainFor "headscale"}" ];
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

        # Force tailscaled to use nftables, avoiding "iptables-compat" translation layer.
        systemd.services.tailscaled.serviceConfig.Environment = [
          "TS_DEBUG_FIREWALL_MODE=nftables"
        ];

        environment.persistence."/persist".directories = [
          "/var/lib/tailscale"
        ];
      };
  };
}
