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
        device_id = "nvme-KINGSTON_OM8PGP41024Q-A0_50026B738300BDD8";
        swap_size = 8192;
      };
      longhorn_drive = {
        device_id = "nvme-Force_MP600_192482300001285610CF";
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
