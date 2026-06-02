{
  den.aspects.services.k3s.base = {
    nixos = {
      networking.nftables.enable = true;
      networking.firewall.filterForward = true;
    };
  };
}
