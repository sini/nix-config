{ pkgs, ... }:
{
  imports = [
    ../shared/boot.nix
  ];

  facter.reportPath = ./facter.json;

  topology.self = {
    hardware.info = "surge";
    services.k8s.name = "k8s";
  };

  hardware.disk.raid = {
    enable = true;
    btrfs_profile = "single";
  };

  hardware.networking.enable = false;
  #networking.eno1.ipv4.addresses = [ "10.10.10.6" ];
  #networking.enp2s0.ipv4.addresses = [ "10.10.10.5" ];

  # Networking
  systemd.network = {
    enable = true;
    netdevs = {
      "10-bond0" = {
        netdevConfig = {
          Kind = "bond";
          Name = "bond0";
        };
        bondConfig = {
          # Mode = "balance-rr";
          # Mode = "balance-alb";
          Mode = "balance-xor";
          TransmitHashPolicy = "layer3+4";
        };
      };
    };
    # Configure Bonds to utilize both 2.5Gbps ports
    networks = {
      "30-eno1" = {
        matchConfig.Name = "eno1";
        networkConfig.Bond = "bond0";
      };

      "30-enp2s0" = {
        matchConfig.Name = "enp2s0";
        networkConfig.Bond = "bond0";
      };

      "40-bond0" = {
        matchConfig.Name = "bond0";
        linkConfig = {
          RequiredForOnline = "routable";
        };
        address = [ "10.10.10.5/16" ];
        gateway = [ "10.10.0.1" ];
        routes = [
          { Gateway = "10.10.0.1"; }
        ];
      };
    };
  };

  networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];
  networking.firewall.enable = false;

  services.ssh.enable = true;
  programs.dconf.enable = true;

  system.nix.enable = true;
  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";


  environment.systemPackages = with pkgs; [
    # Any particular packages only for this host
    wget
    vim
    git
    doas
    doas-sudo-shim
  ];

  services = {
    rpcbind.enable = true; # needed for NFS
  };

  # ======================== DO NOT CHANGE THIS ========================
  system.stateVersion = "24.11";
  # ======================== DO NOT CHANGE THIS ========================
}
