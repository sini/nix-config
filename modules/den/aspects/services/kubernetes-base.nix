# Base Kubernetes configuration — nftables and forward filtering.
{ den, ... }:
{
  den.aspects.kubernetes-base = den.lib.perHost {
    nixos = {
      networking.nftables.enable = true; # Also defined in tailscale
      networking.firewall.filterForward = true;
    };
  };
}
