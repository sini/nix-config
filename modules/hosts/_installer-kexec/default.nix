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

  # Add SSH keys for root user (for nixos-anywhere)
  users.users.root.openssh.authorizedKeys.keys = [
    # sini's keys
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC2KomSUc6hK7QyOCb1AAG00S7ZqVeXqGKvS0po5HishO6YFgr9cPvST6rdxAYreO6b20bLQ8e4Rns3yrGNekWww8Yl32dFdmv0sC1VPZrfJPFKg0qC+imjk3vGDohYII9/3cyDBBb2WuZzupCGSTi+g14AA6/csJXYwN0bQfh/XmLp1OrbrFzmCZEwAWFni95DNMo5WxLeqdUXJxM6is77AzLYbRX7TQqBvdaTyyGjzh6uVi6CkDVJSnhMp3kPRhzqudXyW1RN680U+tgsyDhX+S5AHxgqHZ1OWLkKl+N87ov77rawGXVUEQO1d2ZnOcIwnTQak6rgyiLtPKY81if7mQm53LB0sEsM7Czm9sv1J0RbnR7HwjoygIApDeD29xfTvM4WlYpIn3pk1auS/ZTLQVqg8tx/WhNko5n+DsWCcSIPZ/chu3vs3dvegbYn9QTbEMfHxMp5iLbb3EOmNG08z9M+MQ2gIzbsDPE5KgsEfW84omc9iWy4JvEfvpPyOEKiRf7Ou8bawPDP6tvJv8P7fwEyxfRmhya8hM+ThbUEmPYydwUXJHZ2BkIXk+/1LsTg1lmfADqYb0i2I++1T3C7NbSvYsQ0BobQrIiulkVWzvb/1KuuRcGr4bRxxumJNzmmLWUJLUnWV/ya2h4FAoM/uRPyICGfGeejyycXN1q5mQ== cardno:31_057_490"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDL5nilYJ19sPQPn2Kn07pxuTBmrExbXsmrirLmMWNVh4KLZ2dwl4MFce6/h3b6uY+qijVHNDP5W9BrhMjIK6pbnpPZ4hDNtIoMSkzS1Gjxx5fp6LVoH0Mrf8wZa8JGuZjN088AGFpJ5apBrdw/HpYXwy28m+hwcILsDyF0zEYr7FbcesmenGCHtsSinLp+M9Mfj1bD/w3tFvzsX7FAZGh9ZceVjkgBkodsZAEtFKD2jmRFKviGLSvRrLsO7ZwD9CiZps39KN/jf+3Cxo49wfvISLm4IgqAOld9BCUmn9Jzc9hs56Ry+YKkeR4v3C54sWn77xWZm0zuIwO0cASkzsjTJ1OZ8z3v6g8el2iWqLntbSvtAqZXvnWScArGIuLsTJoGXX2H2j0d99drLX15vtHaIkz89qGgRXZ4rhweDfLv4fiYodMccxC1PgIjpvJURcDa3Ww+3WO0bUbX/JWHH58abmhjBJAlqlzKQBt01JW7soe3t4vDNVNjm7WeZlyVHmWYwBAhBFlTRg4Di0fgAeLt4yhB8mNBiZodlHKclL2u2qU2Ckyb+96nVS2kyxdwI6YaZ8MPgAVb3L+bz9BHHKgE0W/SLU5DejP2Q1EqtrrKy9M8PBHeb5VP1a7y41gdntbkpWmfLaSMzbuqArnVNDhSR0DT35aqOdSeASIAGsWo/Q== sini@ipad"
    # will's key
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMKKUMmeJtEOYi6rU0tumxlrZjH9Y3FCyOhVFIpu3LF1 will.t.bryant@gmail.com"
  ];

  # Provide useful tools for installation
  environment.systemPackages = with pkgs; [
    git
    vim
    tmux
  ];

  # Set a readable hostname
  networking.hostName = "nixos-kexec-installer";

  # Ensure network is enabled and properly configured
  # Note: netboot-minimal.nix handles network configuration via dhcpcd, not networkd
  networking.useDHCP = lib.mkDefault true;

  # Disable networkd wait-online since netboot uses dhcpcd for networking
  systemd.services.systemd-networkd-wait-online.enable = lib.mkForce false;

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
