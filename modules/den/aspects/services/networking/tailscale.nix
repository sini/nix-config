{ lib, ... }:
{
  den.aspects.services.networking.tailscale = {
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

    age-secrets =
      { environment, host, ... }:
      let
        rekeyFile = host.secretPath + "/tailscale-preauthkey.age";
      in
      {
        age.secrets.tailscale-auth-key = {
          inherit rekeyFile;
          settings = {
            headscaleHost = environment.getDomainFor "headscale";
            user = host.name;
          };
          generator.script = "tailscale-preauthkey";
        };
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
        rekeyFile = host.secretPath + "/tailscale-preauthkey.age";
        secretExists = builtins.pathExists rekeyFile;
        authKeyPath = config.age.secrets.tailscale-auth-key.path;
      in
      lib.mkIf secretExists {
        services.tailscale.enable = true;

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
              echo "Authenticating Tailscale with hostname ${host.name}..."
              # Use --reset to clear any conflicting non-default settings
              /run/current-system/sw/bin/tailscale up \
                --login-server=https://${environment.getDomainFor "headscale"} \
                --auth-key="$(cat ${authKeyPath})" \
                --hostname="${host.name}" \
                --reset \
                || echo "Tailscale auth failed (may need manual login)"
            fi
          else
            echo "Warning: Tailscale auth key not found at ${authKeyPath}"
            echo "Run: agenix generate to add tailscale-auth"
          fi
        '';
      };

    persist = {
      directories = [
        "/var/lib/tailscale"
      ];
    };
  };
}
