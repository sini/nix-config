{
  flake.modules.nixos.host_axon-03 =
    {
      pkgs,
      ...
    }:
    {
      networking.domain = "json64.dev";

      boot.kernelPackages = pkgs.linuxPackages_latest;

      hardware = {
        disk.longhorn = {
          os_drive = {
            device_id = "nvme-KINGSTON_OM8PGP41024Q-A0_50026B738300CCCC";
            swap_size = 8192;
          };
          longhorn_drive = {
            device_id = "nvme-Force_MP600_1925823000012856500E";
          };
        };
      };

      # ======================== DO NOT CHANGE THIS ========================
      system.stateVersion = "25.05";
      # ======================== DO NOT CHANGE THIS ========================
    };
}
