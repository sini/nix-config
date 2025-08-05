{
  flake.modules.nixos.host_axon-02 =
    {
      pkgs,
      ...
    }:
    {
      boot.kernelPackages = pkgs.linuxPackages_latest;

      hardware = {
        disk.longhorn = {
          os_drive = {
            device_id = "nvme-KINGSTON_OM8PGP41024Q-A0_50026B738300BDD8";
            swap_size = 8192;
          };
          longhorn_drive = {
            device_id = "nvme-Force_MP600_192482300001285610CF";
          };
        };
      };

      # ======================== DO NOT CHANGE THIS ========================
      system.stateVersion = "25.05";
      # ======================== DO NOT CHANGE THIS ========================
    };
}
