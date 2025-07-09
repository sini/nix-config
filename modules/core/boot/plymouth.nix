{
  flake.modules.nixos.systemd-boot = {
    boot = {
      # TODO: add plymouth theming, enable only on workstation/laptop
      plymouth.enable = true;
    };
  };
}
