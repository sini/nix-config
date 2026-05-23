_: {
  den.aspects.services.kubernetes-base = {
    nixos = {
      networking.nftables.enable = true;
      networking.firewall.filterForward = true;
    };
  };
}
