{
  flake.aspects.systemd-boot.nixos = {
    zramSwap.enable = true;
  };
}
