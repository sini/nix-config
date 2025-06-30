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

    networking.enable = true;
  };

  programs.dconf.enable = true;

  environment.systemPackages = with pkgs; [
    # Any particular packages only for this host
    wget
    vim
    git
  ];

  services = {
    # podman.enable = true;
    fstrim.enable = true;
  };

  # ======================== DO NOT CHANGE THIS ========================
  system.stateVersion = "25.05";
  # ======================== DO NOT CHANGE THIS ========================
}
