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
    extra_modules = with config.flake.modules.nixos; [
      ./_local
      cpu-intel
      gpu-intel
      gpu-nvidia
      gpu-nvidia-prime
      razer
    ];
    facts = ./facter.json;
    nixosConfiguration = {
      # Enable NetworkManager for managing network interfaces
      networking.networkmanager.enable = true;
    };
  };
}
