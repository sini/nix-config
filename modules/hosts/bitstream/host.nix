{
  flake.hosts.bitstream = {
    ipv4 = [
      "10.9.1.1"
      "10.9.1.2"
    ];
    ipv6 = [
      "2001:5a8:608c:4a00::1/64"
      "2001:5a8:608c:4a00::2/64"
    ];
    environment = "dev";
    roles = [
      "server"
      "workstation"
      "dev"
      "dev-gui"
      "media"
      "nix-builder"
    ];
    features = [
      "disk-single"
      "cpu-amd"
      "gpu-amd"
      "podman"
    ];
    users = {
      media = {
        enableUnixAccount = true;
        uid = 1027;
        gid = 65536;
        linger = true;
        displayName = "Media user for rootless podman";
        groups = [ ];
        systemGroups = [
          "video"
          "render"
          "podman"
          "input"
          "tty"
        ];
        sshKeys = [
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC2KomSUc6hK7QyOCb1AAG00S7ZqVeXqGKvS0po5HishO6YFgr9cPvST6rdxAYreO6b20bLQ8e4Rns3yrGNekWww8Yl32dFdmv0sC1VPZrfJPFKg0qC+imjk3vGDohYII9/3cyDBBb2WuZzupCGSTi+g14AA6/csJXYwN0bQfh/XmLp1OrbrFzmCZEwAWFni95DNMo5WxLeqdUXJxM6is77AzLYbRX7TQqBvdaTyyGjzh6uVi6CkDVJSnhMp3kPRhzqudXyW1RN680U+tgsyDhX+S5AHxgqHZ1OWLkKl+N87ov77rawGXVUEQO1d2ZnOcIwnTQak6rgyiLtPKY81if7mQm53LB0sEsM7Czm9sv1J0RbnR7HwjoygIApDeD29xfTvM4WlYpIn3pk1auS/ZTLQVqg8tx/WhNko5n+DsWCcSIPZ/chu3vs3dvegbYn9QTbEMfHxMp5iLbb3EOmNG08z9M+MQ2gIzbsDPE5KgsEfW84omc9iWy4JvEfvpPyOEKiRf7Ou8bawPDP6tvJv8P7fwEyxfRmhya8hM+ThbUEmPYydwUXJHZ2BkIXk+/1LsTg1lmfADqYb0i2I++1T3C7NbSvYsQ0BobQrIiulkVWzvb/1KuuRcGr4bRxxumJNzmmLWUJLUnWV/ya2h4FAoM/uRPyICGfGeejyycXN1q5mQ== cardno:31_057_490"
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDL5nilYJ19sPQPn2Kn07pxuTBmrExbXsmrirLmMWNVh4KLZ2dwl4MFce6/h3b6uY+qijVHNDP5W9BrhMjIK6pbnpPZ4hDNtIoMSkzS1Gjxx5fp6LVoH0Mrf8wZa8JGuZjN088AGFpJ5apBrdw/HpYXwy28m+hwcILsDyF0zEYr7FbcesmenGCHtsSinLp+M9Mfj1bD/w3tFvzsX7FAZGh9ZceVjkgBkodsZAEtFKD2jmRFKviGLSvRrLsO7ZwD9CiZps39KN/jf+3Cxo49wfvISLm4IgqAOld9BCUmn9Jzc9hs56Ry+YKkeR4v3C54sWn77xWZm0zuIwO0cASkzsjTJ1OZ8z3v6g8el2iWqLntbSvtAqZXvnWScArGIuLsTJoGXX2H2j0d99drLX15vtHaIkz89qGgRXZ4rhweDfLv4fiYodMccxC1PgIjpvJURcDa3Ww+3WO0bUbX/JWHH58abmhjBJAlqlzKQBt01JW7soe3t4vDNVNjm7WeZlyVHmWYwBAhBFlTRg4Di0fgAeLt4yhB8mNBiZodlHKclL2u2qU2Ckyb+96nVS2kyxdwI6YaZ8MPgAVb3L+bz9BHHKgE0W/SLU5DejP2Q1EqtrrKy9M8PBHeb5VP1a7y41gdntbkpWmfLaSMzbuqArnVNDhSR0DT35aqOdSeASIAGsWo/Q== sini@ipad"
        ];
      };
    };
    facts = ./facter.json;
    nixosConfiguration =
      { pkgs, ... }:
      {
        boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest-lto;

        hardware = {
          disk.single = {
            device_id = "nvme-NVMe_CA6-8D1024_0023065001TG";
            swap_size = 8192;
          };
          networking = {
            interfaces = [
              "eno1"
              "enp2s0"
            ];
          };
        };

        # systemd.network = {
        #   netdevs = {
        #     "10-bond0" = {
        #       netdevConfig = {
        #         Kind = "bond";
        #         Name = "bond0";
        #       };
        #       bondConfig = {
        #         # Mode = "balance-alb";
        #         Mode = "balance-xor";
        #         TransmitHashPolicy = "layer3+4";
        #       };
        #     };
        #   };

        #   # Configure Bonds to utilize both 2.5Gbps ports
        #   networks = {
        #     "30-eno1" = {
        #       enable = true;
        #       matchConfig.PermanentMACAddress = "84:47:09:40:d5:f5";
        #       networkConfig.Bond = "bond0";
        #     };

        #     "30-enp2s0" = {
        #       enable = true;
        #       matchConfig.PermanentMACAddress = "84:47:09:40:d5:f4";
        #       networkConfig.Bond = "bond0";
        #     };

        #     "40-bond0" = {
        #       enable = true;
        #       matchConfig.Name = "bond0";
        #       networkConfig = {
        #         DHCP = true;
        #         LinkLocalAddressing = "no";
        #       };
        #       linkConfig = {
        #         RequiredForOnline = "routable";
        #         MACAddress = "84:47:09:40:d5:f4";
        #       };
        #     };
        #   };
        # };
        networking.firewall.allowedTCPPorts = [
          12365
          53
        ];

        impermanence = {
          enable = false;
          wipeRootOnBoot = false;
          wipeHomeOnBoot = false;
        };

        system.stateVersion = "25.05";
      };
  };
}
