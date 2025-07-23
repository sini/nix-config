{
  flake.modules.nixos.systemd-boot = {
    zramSwap.enable = true;
  };
}
