{ config, ... }:
{
  flake.hosts.shell = {
    ipv4 = [
      "10.9.2.2"
    ];
    ipv6 = [
      "2001:5a8:608c:4a00::22/64"
    ];
    environment = "dev";
    roles = [
      "server"
      "laptop"
    ];
    extra_modules = with config.flake.aspects; [
      disk-single.nixos
      cpu-intel.nixos
      gpu-intel.nixos
      podman.nixos
    ];
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
