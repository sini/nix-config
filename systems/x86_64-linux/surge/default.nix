{
  pkgs,
  ...
}:
{

  networking.hostName = "surge";

  # sops.secrets."network/eno1/mac" = {
  #   sopsFile = lib.custom.relativeToRoot "secrets/${config.networking.hostName}/secrets.yaml";
  # };

  facter.reportPath = ./facter.json;

  # topology.self = {
  #   hardware.info = "surge";
  #   services.k8s.name = "k8s";
  # };

  hardware.disk.raid = {
    enable = true;
    btrfs_profile = "single";
  };

  system.security.doas.enable = true;

  # hardware.networking.enable = false;

  systemd.network = {
    enable = true;
    netdevs = {
      "10-bond0" = {
        netdevConfig = {
          Kind = "bond";
          Name = "bond0";
        };
        bondConfig = {
          Mode = "balance-xor";
          TransmitHashPolicy = "layer3+4";
        };
      };
    };
    # Configure Bonds to utilize both 2.5Gbps ports
    networks = {
      "30-eno1" = {
        matchConfig.PermanentMACAddress = "84:47:09:40:d5:f5";
        networkConfig.Bond = "bond0";
      };

      "30-enp2s0" = {
        matchConfig.PermanentMACAddress = "84:47:09:40:d5:f4";
        networkConfig.Bond = "bond0";
      };

      "40-bond0" = {
        matchConfig.Name = "bond0";
        networkConfig = {
          DHCP = "ipv4";
          LinkLocalAddressing = "no";
        };
        linkConfig = {
          RequiredForOnline = "routable";
          MACAddress = "84:47:09:40:d5:f4";
        };
      };
    };
  };

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
  ];

  services = {
    rpcbind.enable = true; # needed for NFS
  };

  # ======================== DO NOT CHANGE THIS ========================
  system.stateVersion = "24.11";
  # ======================== DO NOT CHANGE THIS ========================
}
