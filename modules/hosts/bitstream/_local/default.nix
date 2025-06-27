{
  pkgs,
  ...
}:
{
  imports = [
    # Custom modules for this host
    ./networking.nix
  ];

  # TODO: Convert back to a kubernetes node, for now we'll test desktop/home manager configuration before adding to the config
  node = {
    deployment.targetHost = "10.10.10.5";
    tags = [
      "server"
      # "kubernetes"
      # "kubernetes-master"
    ];
  };
  networking.domain = "json64.dev";

  boot.kernelPackages = pkgs.linuxPackages_latest;

  hardware = {
    gpu.amd.enable = true;

    disk.single = {
      enable = true;
      device_id = "nvme-NVMe_CA6-8D1024_0023065001TG";
      swap_size = 8192;
    };
  };

  networking.firewall.enable = false;

  services.ssh.enable = true;
  programs.dconf.enable = true;

  system = {
    nix.enable = true;
    security.doas.enable = true;
  };

  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";

  environment.systemPackages = with pkgs; [
    # Any particular packages only for this host
    wget
    vim
    git
  ];

  services = {
    # podman.enable = true;
    fstrim.enable = true;
    custom.media.data-share.enable = true;
    rpcbind.enable = true; # needed for NFS
    # X server stuff
    xserver = {
      enable = true;
      displayManager = {
        gdm = {
          enable = true;
          autoSuspend = false;
          wayland = true;
        };
      };
      desktopManager = {
        gnome.enable = true;
      };
      xkb = {
        layout = "us";
        variant = "";
      };
    };

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      # If you want to use JACK applications, uncomment this
      #jack.enable = true;
      # use the example session manager (no others are packaged yet so this is enabled by default,
      # no need to redefine it in your config for now)
      #media-session.enable = true;
    };
  };

  programs = {
    firefox.enable = true;
    xwayland.enable = true;
  };

  # ======================== DO NOT CHANGE THIS ========================
  system.stateVersion = "25.05";
  # ======================== DO NOT CHANGE THIS ========================
}
