{
  pkgs,
  ...
}:
{
  imports = [
    ./disko.nix
    ./home.nix
    ./razer.nix
    ./user.nix
  ];

  boot.kernelPackages = pkgs.linuxPackages_cachyos;
  # boot.kernelPackages = pkgs.linuxPackages_6_15;

  boot = {
    initrd.availableKernelModules = [
      "xhci_pci"
      "thunderbolt"
      "nvme"
      "usbhid"
      "usb_storage"
      "sd_mod"
      "rtsx_pci_sdmmc"
    ];
    kernelModules = [
      "kvm-intel"
      "iwlmvm"
      "iwlwifi"
      "mmc_core"
      "mt76"
      "mt7921e"
    ];
  };

  hardware = {
    gpgSmartcards.enable = true;
    networking.enable = false;
  };

  systemd = {
    services.NetworkManager-wait-online.enable = false;
    network.wait-online.enable = false;
  };

  networking = {
    networkmanager.enable = true;
    firewall.enable = false;
  };

  networking.domain = "json64.dev";
  systemd.network.wait-online.anyInterface = true;

  programs.dconf.enable = true;

  environment.systemPackages = with pkgs; [
    # Any particular packages only for this host
    wget
    vim
    git
    gitkraken
    krita
    pavucontrol
  ];

  services = {
    # podman.enable = true;
    fstrim.enable = true;
    # yubikey...
    pcscd.enable = true;
    # X server stuff
    desktopManager = {
      gnome.enable = true;
    };
    displayManager = {
      gdm = {
        enable = true;
        autoSuspend = false;
        wayland = true;
      };
    };
    xserver = {
      enable = true;

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
