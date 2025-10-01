{ config, ... }:
{
  flake.hosts.spike = {
    ipv4 = [ "10.9.3.1" ];
    ipv6 = [ "2001:5a8:608c:4a00::31/64" ];
    environment = "dev";
    roles = [
      "workstation"
      "laptop"
      "gaming"
      "dev"
      "dev-gui"
      "media"
    ];
    extra_modules = with config.flake.aspects; [
      ./_local
      cpu-intel.nixos
      gpu-intel.nixos
      gpu-nvidia.nixos
      gpu-nvidia-prime.nixos
      razer.nixos
    ];
    facts = ./facter.json;
    nixosConfiguration = {
      # Enable NetworkManager for managing network interfaces
      networking.networkmanager.enable = true;
    };
  };
}
