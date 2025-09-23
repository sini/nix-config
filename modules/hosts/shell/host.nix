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
    ];
    extra_modules = with config.flake.modules.nixos; [
      disk-single
      cpu-intel
      gpu-intel
      podman
      performance
    ];
    public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKm4x6WUgpQHRtnA6yhY/ECpsRG7CwY0aBvi4PFA9q1G";
    facts = ./facter.json;
    nixosConfiguration =
      {
        pkgs,
        ...
      }:
      {
        boot.kernelPackages = pkgs.linuxPackages_cachyos-gcc; # TODO: https://github.com/chaotic-cx/nyx/issues/1178
        system.stateVersion = "25.05";
      };
  };
}
