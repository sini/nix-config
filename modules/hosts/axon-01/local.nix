{
  flake.modules.nixos.host_axon-01 =
    {
      pkgs,
      ...
    }:
    {

      networking.domain = "json64.dev";

      boot.kernelPackages = pkgs.linuxPackages_latest;

      hardware = {
        disk.longhorn = {
          enable = true;
          os_drive = {
            device_id = "nvme-NVMe_CA6-8D1024_00230650035M";
            swap_size = 8192;
          };
          longhorn_drive = {
            device_id = "nvme-Samsung_SSD_990_PRO_2TB_S73WNJ0W310395L";
          };
        };

        gpu.amd.enable = true;

        networking.enable = true;
      };

      programs.dconf.enable = true;

      environment.systemPackages = with pkgs; [
        # Any particular packages only for this host
        wget
        vim
        git
        doas
        doas-sudo-shim
      ];

      services = {
        # podman.enable = true;
        fstrim.enable = true;
      };

      # ======================== DO NOT CHANGE THIS ========================
      system.stateVersion = "25.05";
      # ======================== DO NOT CHANGE THIS ========================
    };

}
