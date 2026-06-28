# Tailscale on Darwin — enables the service and authenticates on activation,
# since nix-darwin has no declarative authKeyFile equivalent.
{ lib, ... }:
{
  den.aspects.core.network.tailscale.darwin =
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

      # MagicDNS parity with the Linux hosts. The open-source `tailscaled` we run
      # under launchd (no GUI network-extension) does not program the macOS
      # resolver, so MagicDNS names never resolve on their own — nix-darwin's
      # tailscale module compensates, but only for the default `ts.net` base
      # domain. This fleet's headscale uses a custom base domain
      # (`ts.${environment.domain}`), so mirror that handling: route just the
      # tailnet zone to tailscale's internal resolver (100.100.100.100, which
      # answers MagicDNS and forwards the rest). Public `${environment.domain}`
      # names stay on the normal resolver, so general DNS keeps working when this
      # laptop roams off the tailnet.
      environment.etc."resolver/ts.${environment.domain}".text = "nameserver 100.100.100.100";

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

          # Make sure the node accepts the control plane's pushed DNS config, so
          # tailscale's internal resolver (100.100.100.100, the nameserver the
          # /etc/resolver/ts.${environment.domain} entry points at) answers
          # MagicDNS. `up --reset` defaults this on, but set it idempotently so a
          # node that was already connected before this change also picks it up.
          /run/current-system/sw/bin/tailscale set --accept-dns=true 2>/dev/null || true
        else
          echo "Warning: Tailscale auth key not found at ${authKeyPath}"
          echo "Run: agenix generate to add tailscale-auth"
        fi

        # macOS caches resolver configuration in mDNSResponder, so a freshly
        # written /etc/resolver/ts.${environment.domain} entry is not consulted
        # until the cache is flushed (or the machine reboots). nix-darwin writes
        # the file but does not flush, so do it here — otherwise MagicDNS stays
        # broken until the next reboot after this switch.
        /usr/bin/dscacheutil -flushcache 2>/dev/null || true
        /usr/bin/killall -HUP mDNSResponder 2>/dev/null || true
      '';
    };
}
