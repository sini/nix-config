{
  features.kubernetes-base.linux = {
    networking.nftables.enable = true; # Also defined in tailscale
    networking.firewall.filterForward = true;
  };
}
