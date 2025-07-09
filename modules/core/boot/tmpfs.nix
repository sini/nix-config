{
  flake.modules.nixos.systemd-boot = {
    boot.tmp = {
      useTmpfs = true;
      cleanOnBoot = true;
    };
  };
}
