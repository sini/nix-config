{ config, ... }:
{
  flake.hosts.shell = {
    ipv4 = [
      "10.10.10.8"
    ];
    ipv6 = [
      "2001:5a8:608c:4a00::8/64"
    ];
    environment = "dev";
    roles = [
      "server"
      "laptop"
    ];
    extra_modules = with config.flake.modules.nixos; [
      disk-single
      cpu-intel
      gpu-intel
      podman
    ];
    public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEzXeBwtKLEBtkCwn9VT8hbEw1Ll8/5YRNONaKYhCAFp";
    facts = ./facter.json;
    nixosConfiguration =
      {
        pkgs,
        ...
      }:
      {
        boot.kernelPackages = pkgs.linuxPackages_cachyos-gcc; # TODO: https://github.com/chaotic-cx/nyx/issues/1178

        hardware.networking.interfaces = [ "wlp3s0" ];

        system.stateVersion = "25.05";
      };
  };
}
