{
  inputs,
  config,
  pkgs,
  ...
}:
{
  imports = [
    ../shared/boot.nix
    ../../modules/nixos/system/security/sops
    ../../modules/nixos/hardware/disk/raid
  ];

  networking.hostName = "surge";
  sops = {
    defaultSopsFile = "${inputs.self}/secrets/global/secrets.yaml";
    age = {
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = true;
    };
    validateSopsFiles = true;
  };

  sops.secrets."network/eno1/mac" = {
    sopsFile = "${inputs.self}/secrets/${config.networking.hostName}/secrets.yaml";
  };

  facter.reportPath = ./facter.json;

  # topology.self = {
  #   hardware.info = "surge";
  #   services.k8s.name = "k8s";
  # };

  hardware.disk.raid = {
    enable = true;
    btrfs_profile = "single";
  };

  # system.security.doas.enable = true;

<<<<<<< HEAD
=======
  # hardware.networking.enable = false;

>>>>>>> 4f24581 (stash)
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

  # services.ssh.enable = true;
  programs.dconf.enable = true;

  #system.nix.enable = true;
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

  users.users.sini = {
    isNormalUser = true;
    # inherit (cfg) name initialPassword;
    initialHashedPassword = "$y$j9T$RpfkDk8AusZr9NS09tJ9e.$kbc4SL9Cu45o1YYPlyV1jiVTZZ/126ue5Nff2Rfgpw8";

    home = "/home/sini";
    group = "users";

    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC2KomSUc6hK7QyOCb1AAG00S7ZqVeXqGKvS0po5HishO6YFgr9cPvST6rdxAYreO6b20bLQ8e4Rns3yrGNekWww8Yl32dFdmv0sC1VPZrfJPFKg0qC+imjk3vGDohYII9/3cyDBBb2WuZzupCGSTi+g14AA6/csJXYwN0bQfh/XmLp1OrbrFzmCZEwAWFni95DNMo5WxLeqdUXJxM6is77AzLYbRX7TQqBvdaTyyGjzh6uVi6CkDVJSnhMp3kPRhzqudXyW1RN680U+tgsyDhX+S5AHxgqHZ1OWLkKl+N87ov77rawGXVUEQO1d2ZnOcIwnTQak6rgyiLtPKY81if7mQm53LB0sEsM7Czm9sv1J0RbnR7HwjoygIApDeD29xfTvM4WlYpIn3pk1auS/ZTLQVqg8tx/WhNko5n+DsWCcSIPZ/chu3vs3dvegbYn9QTbEMfHxMp5iLbb3EOmNG08z9M+MQ2gIzbsDPE5KgsEfW84omc9iWy4JvEfvpPyOEKiRf7Ou8bawPDP6tvJv8P7fwEyxfRmhya8hM+ThbUEmPYydwUXJHZ2BkIXk+/1LsTg1lmfADqYb0i2I++1T3C7NbSvYsQ0BobQrIiulkVWzvb/1KuuRcGr4bRxxumJNzmmLWUJLUnWV/ya2h4FAoM/uRPyICGfGeejyycXN1q5mQ== cardno:31_057_490"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAOa9kFogEBODAU4YVs4hxfVx3b5ryBzct4HoAHgwPio jason.bowman@pm.me"
    ];

    extraGroups = [
      "wheel"
      "audio"
      "sound"
      "video"
      "networkmanager"
      "input"
      "tty"
      "docker"
    ];
  };

  # ======================== DO NOT CHANGE THIS ========================
  system.stateVersion = "24.11";
  # ======================== DO NOT CHANGE THIS ========================
}
