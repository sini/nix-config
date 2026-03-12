{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:
let
  # Static binaries for kexec
  iprouteStatic = pkgs.pkgsStatic.iproute2.override { iptables = null; };

  # Kexec installer name
  kexecInstallerName = "nixos-kexec-installer-noninteractive";
in
{
  imports = [
    (modulesPath + "/installer/netboot/netboot-minimal.nix")
  ];

  # Enable SSH in the installer and ensure it starts
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  # Ensure SSH starts after network is ready
  systemd.services.sshd = {
    wantedBy = lib.mkForce [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };

  # Enable interactive console access via serial and TTY with verbose logging
  # This allows debugging if SSH doesn't work
  boot.kernelParams = [
    "console=tty1"
    "console=ttyS0,115200n8"
    "boot.shell_on_fail"
    "debug"
    "systemd.log_level=debug"
    "systemd.log_target=console"
  ];

  # Enable getty on tty1 for local console access
  systemd.services."getty@tty1" = {
    enable = true;
    wantedBy = [ "multi-user.target" ];
  };

  # Enable serial console
  systemd.services."serial-getty@ttyS0" = {
    enable = true;
    wantedBy = [ "multi-user.target" ];
  };

  # Allow root login without password on console (for debugging)
  users.users.root.initialHashedPassword = lib.mkForce "";

  # Add a debug service that outputs network and system status
  systemd.services.installer-debug = {
    description = "Kexec Installer Debug Info";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "sshd.service"
    ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StandardOutput = "journal+console";
      StandardError = "journal+console";
    };
    script = ''
      echo ""
      echo "============================================"
      echo "  NixOS Kexec Installer Ready"
      echo "============================================"
      echo "Hostname: $(hostname)"
      echo ""
      echo "IP Addresses:"
      ${pkgs.iproute2}/bin/ip -br addr show | grep -v "^lo" || true
      echo ""
      echo "Full network configuration:"
      ${pkgs.iproute2}/bin/ip addr show
      echo ""
      echo "Routes:"
      ${pkgs.iproute2}/bin/ip route show
      echo ""
      echo "DNS Configuration:"
      cat /etc/resolv.conf || true
      echo ""
      echo "SSH Service Status:"
      systemctl status sshd --no-pager || true
      echo ""
      echo "Listening Ports:"
      ${pkgs.nettools}/bin/netstat -tlnp || true
      echo ""
      echo "============================================"
      echo "  Try: ssh root@<ip-address>"
      echo "  Password: (none - key-based auth only)"
      echo "============================================"
      echo ""
    '';
  };

  # Early boot message
  systemd.services.installer-boot-message = {
    description = "Kexec Installer Boot Message";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-networkd.service" ];
    before = [ "sshd.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StandardOutput = "journal+console";
    };
    script = ''
      echo ""
      echo ">>> NixOS Kexec Installer is booting..."
      echo ">>> Waiting for network configuration..."
    '';
  };

  # Restore network configuration from pre-kexec state
  systemd.services.restore-network = {
    description = "Restore Network Configuration After Kexec";
    wantedBy = [ "network-pre.target" ];
    before = [ "systemd-networkd.service" ];
    after = [ "systemd-networkd.socket" ];
    conflicts = [ "shutdown.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    # Only run if network state was saved
    unitConfig.ConditionPathExists = [
      "/root/network/addrs.json"
      "/root/network/routes-v4.json"
      "/root/network/routes-v6.json"
    ];
    script = ''
      echo "Restoring network configuration from /root/network..." > /dev/console
      ${pkgs.python3}/bin/python3 ${./restore-network.py} \
        /root/network/addrs.json \
        /root/network/routes-v4.json \
        /root/network/routes-v6.json \
        /etc/systemd/network

      # Restart networkd to apply configuration
      systemctl restart systemd-networkd
      echo "Network configuration restored" > /dev/console
    '';
  };

  # Add SSH keys for root user (for nixos-anywhere)
  users.users.root.openssh.authorizedKeys.keys = [
    # sini's keys
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC2KomSUc6hK7QyOCb1AAG00S7ZqVeXqGKvS0po5HishO6YFgr9cPvST6rdxAYreO6b20bLQ8e4Rns3yrGNekWww8Yl32dFdmv0sC1VPZrfJPFKg0qC+imjk3vGDohYII9/3cyDBBb2WuZzupCGSTi+g14AA6/csJXYwN0bQfh/XmLp1OrbrFzmCZEwAWFni95DNMo5WxLeqdUXJxM6is77AzLYbRX7TQqBvdaTyyGjzh6uVi6CkDVJSnhMp3kPRhzqudXyW1RN680U+tgsyDhX+S5AHxgqHZ1OWLkKl+N87ov77rawGXVUEQO1d2ZnOcIwnTQak6rgyiLtPKY81if7mQm53LB0sEsM7Czm9sv1J0RbnR7HwjoygIApDeD29xfTvM4WlYpIn3pk1auS/ZTLQVqg8tx/WhNko5n+DsWCcSIPZ/chu3vs3dvegbYn9QTbEMfHxMp5iLbb3EOmNG08z9M+MQ2gIzbsDPE5KgsEfW84omc9iWy4JvEfvpPyOEKiRf7Ou8bawPDP6tvJv8P7fwEyxfRmhya8hM+ThbUEmPYydwUXJHZ2BkIXk+/1LsTg1lmfADqYb0i2I++1T3C7NbSvYsQ0BobQrIiulkVWzvb/1KuuRcGr4bRxxumJNzmmLWUJLUnWV/ya2h4FAoM/uRPyICGfGeejyycXN1q5mQ== cardno:31_057_490"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDL5nilYJ19sPQPn2Kn07pxuTBmrExbXsmrirLmMWNVh4KLZ2dwl4MFce6/h3b6uY+qijVHNDP5W9BrhMjIK6pbnpPZ4hDNtIoMSkzS1Gjxx5fp6LVoH0Mrf8wZa8JGuZjN088AGFpJ5apBrdw/HpYXwy28m+hwcILsDyF0zEYr7FbcesmenGCHtsSinLp+M9Mfj1bD/w3tFvzsX7FAZGh9ZceVjkgBkodsZAEtFKD2jmRFKviGLSvRrLsO7ZwD9CiZps39KN/jf+3Cxo49wfvISLm4IgqAOld9BCUmn9Jzc9hs56Ry+YKkeR4v3C54sWn77xWZm0zuIwO0cASkzsjTJ1OZ8z3v6g8el2iWqLntbSvtAqZXvnWScArGIuLsTJoGXX2H2j0d99drLX15vtHaIkz89qGgRXZ4rhweDfLv4fiYodMccxC1PgIjpvJURcDa3Ww+3WO0bUbX/JWHH58abmhjBJAlqlzKQBt01JW7soe3t4vDNVNjm7WeZlyVHmWYwBAhBFlTRg4Di0fgAeLt4yhB8mNBiZodlHKclL2u2qU2Ckyb+96nVS2kyxdwI6YaZ8MPgAVb3L+bz9BHHKgE0W/SLU5DejP2Q1EqtrrKy9M8PBHeb5VP1a7y41gdntbkpWmfLaSMzbuqArnVNDhSR0DT35aqOdSeASIAGsWo/Q== sini@ipad"
    # will's key
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMKKUMmeJtEOYi6rU0tumxlrZjH9Y3FCyOhVFIpu3LF1 will.t.bryant@gmail.com"
  ];

  # Provide useful tools for installation and debugging
  environment.systemPackages = with pkgs; [
    git
    vim
    tmux
    htop
    iftop
    tcpdump
    traceroute
    netcat
    curl
    wget
    iproute2
    ethtool
    dnsutils
  ];

  # Set a readable hostname
  networking.hostName = "nixos-kexec-installer";

  # Ensure network is enabled and properly configured
  networking.useDHCP = lib.mkDefault true;
  networking.useNetworkd = true;

  # Enable networkd wait-online to ensure network is up before services start
  systemd.services.systemd-networkd-wait-online = {
    enable = true;
    wantedBy = [ "network-online.target" ];
  };

  # Increase DHCP timeout
  systemd.network.wait-online.timeout = 60;

  # Use xz compression for faster boot
  boot = {
    initrd = {
      compressor = "xz";
      availableKernelModules = [
        "r8169" # Host: surge, burst, pulse
        "mlx4_core"
        "mlx4_en" # Hosts: uplink
        "atlantic" # Hosts: cortex
        "bridge"
        "bonding"
        "8021q"
        "tpm_crb" # TPM support
        "tpm_tis"
      ];
    };
  };
  system = {
    # Build the kexec run script
    build.kexecRun = pkgs.runCommand "kexec-run" { } ''
      install -D -m 0755 ${./kexec-run.sh} $out

      sed -i \
        -e 's|@init@|${config.system.build.toplevel}/init|' \
        -e 's|@kernelParams@|${lib.escapeShellArgs config.boot.kernelParams}|' \
        $out

      ${pkgs.shellcheck}/bin/shellcheck $out
    '';

    # Build the kexec installer tarball
    build.kexecInstallerTarball = pkgs.runCommand "kexec-tarball" { } ''
      mkdir kexec $out
      cp "${config.system.build.netbootRamdisk}/initrd" kexec/initrd
      cp "${config.system.build.kernel}/${config.system.boot.loader.kernelFile}" kexec/bzImage
      cp "${config.system.build.kexecRun}" kexec/run
      cp "${pkgs.pkgsStatic.kexec-tools}/bin/kexec" kexec/kexec
      cp "${iprouteStatic}/bin/ip" kexec/ip
      ${lib.optionalString (pkgs.stdenv.hostPlatform == pkgs.stdenv.buildPlatform) ''
        kexec/ip -V
        kexec/kexec --version
      ''}
      tar -czvf $out/${kexecInstallerName}-${pkgs.stdenv.hostPlatform.system}.tar.gz kexec
    '';

    stateVersion = "25.11";
  };
}
