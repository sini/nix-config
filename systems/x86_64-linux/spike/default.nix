{
  config,
  pkgs,
  lib,
  ...
}:
{
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
    gpu.intel = {
      enable = true;
      device_id = "a788";
    };
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    bluetooth.enable = false;
    enableAllFirmware = true;
    enableRedistributableFirmware = true;
  };

  systemd = {
    services.NetworkManager-wait-online.enable = false;
    network.wait-online.enable = false;
  };

  networking = {
    useDHCP = lib.mkDefault true;
    networkmanager.enable = true;
    firewall.enable = false;
  };

  networking.domain = "json64.dev";
  systemd.network.wait-online.anyInterface = true;

  node = {
    deployment.targetHost = "10.10.9.36";
    tags = [
      "laptop"
      # "kubernetes"
      # "kubernetes-master"
    ];
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;

  facter.reportPath = ./facter.json;

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
    # yubikey...
    pcscd.enable = true;
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
