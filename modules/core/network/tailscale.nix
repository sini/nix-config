{ lib, ... }:
{
  features.tailscale = {
    settings = {
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to open the firewall for Tailscale";
      };
      extraUpFlags = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional flags to pass to tailscale up (login-server is added automatically)";
      };
      extraDaemonFlags = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "--no-logs-no-support" ];
        description = "Additional flags for the tailscale daemon";
      };
      useNftables = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Force tailscaled to use nftables instead of iptables-compat";
      };
    };

    system =
      {
        flakeLib,
        lib,
        environment,
        host,
        ...
      }:
      let
        rekeyFile = host.secretPath + "/tailscale-preauthkey.age";
        delegation = environment.services.headscale.delegateTo or null;
        headscaleHosts =
          if delegation != null then
            flakeLib.host-utils.findHostsWithFeature "headscale"
            |> lib.filterAttrs (_: h: h.environment == delegation)
            |> lib.attrValues
          else
            environment.findHostsByFeature "headscale" |> lib.attrValues;
        headscaleHost = builtins.head headscaleHosts;
      in
      {
        age.secrets.tailscale-auth-key = {
          inherit rekeyFile;
          settings = {
            headscaleHost = builtins.head headscaleHost.ipv4;
            user = host.hostname;
          };
          generator.script = "tailscale-preauthkey";
        };
      };

    darwin =
      {
        config,
        lib,
        environment,
        host,
        pkgs,
        ...
      }:
      let
        rekeyFile = host.secretPath + "/tailscale-preauthkey.age";
        secretExists = builtins.pathExists rekeyFile;
      in
      lib.mkIf secretExists {
        services.tailscale.enable = true;

        system.activationScripts.postActivation.text = ''
          # Tailscale auto-authentication
          if [ -f "${config.age.secrets.tailscale-auth-key.path}" ]; then
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
                --auth-key="$(cat ${config.age.secrets.tailscale-auth-key.path})" \
                --hostname="${host.hostname}" \
                --reset \
                || echo "Tailscale auth failed (may need manual login)"
            fi
          else
            echo "Warning: Tailscale auth key not found at ${config.age.secrets.tailscale-auth-key.path}"
            echo "Run: agenix generate to add tailscale-auth"
          fi
        '';

      };

    linux =
      {
        config,
        lib,
        environment,
        host,
        settings,
        ...
      }:
      let
        rekeyFile = host.secretPath + "/tailscale-preauthkey.age";
        secretExists = builtins.pathExists rekeyFile;
        ts = settings.tailscale;
      in
      lib.mkIf secretExists {
        services.tailscale = {
          enable = true;
          inherit (ts) openFirewall;
          authKeyFile = config.age.secrets.tailscale-auth-key.path;
          extraUpFlags = [
            "--login-server=https://${environment.getDomainFor "headscale"}"
          ]
          ++ ts.extraUpFlags;
          inherit (ts) extraDaemonFlags;
        };

        networking = lib.mkIf ts.openFirewall {
          nftables.enable = true;
          firewall = {
            checkReversePath = "loose";
            trustedInterfaces = [ config.services.tailscale.interfaceName ];
            allowedUDPPorts = [ config.services.tailscale.port ];
          };
        };

        systemd.services.tailscaled.serviceConfig.Environment = lib.mkIf ts.useNftables [
          "TS_DEBUG_FIREWALL_MODE=nftables"
        ];

      };

    provides.impermanence.linux =
      {
        lib,
        host,
        ...
      }:
      let
        rekeyFile = host.secretPath + "/tailscale-preauthkey.age";
        secretExists = builtins.pathExists rekeyFile;
      in
      lib.mkIf secretExists {
        environment.persistence."/persist".directories = [
          "/var/lib/tailscale"
        ];
      };
  };
}
