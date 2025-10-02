{
  flake.features.systemd-boot.nixos = {
    boot.tmp = {
      useTmpfs = true;
      cleanOnBoot = true;
    };
  };
}
