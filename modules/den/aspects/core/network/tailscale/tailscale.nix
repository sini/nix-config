# Tailscale mesh — joins the headscale control plane. Auth key is provisioned
# by the secrets concern (secrets.nix); the daemon runs in nftables mode.
{ den, lib, ... }:
let
  resolvers = import ../_resolvers.nix { inherit lib; };
in
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
        leavesMagicDns = resolvers.leavesMagicDns den.aspects.core.network.manager environment host;
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
          # Owner Q13: servers and guests leave MagicDNS for the LAN resolver, which
          # maps ts.<domain> to quad-100 (docs/dns-resolver.md §2.4b); roaming hosts
          # keep it. `set`, not `up`: up flags apply only at first login.
          extraSetFlags = lib.optional leavesMagicDns "--accept-dns=false";
        };

        networking = {
          nftables.enable = true;
          firewall = {
            checkReversePath = "loose";
            trustedInterfaces = [ config.services.tailscale.interfaceName ];
            allowedUDPPorts = [ config.services.tailscale.port ];
          };
        };

        systemd.services.tailscaled.serviceConfig = {
          Environment = [ "TS_DEBUG_FIREWALL_MODE=nftables" ];
          # When its TUN device closes under it (networkd flushing its ip rules on
          # a switch), tailscaled exits 0, which on-failure does not restart.
          Restart = "always";
        };
      };

    persist = {
      directories = [
        "/var/lib/tailscale"
      ];
    };
  };
}
