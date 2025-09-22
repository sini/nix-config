{ config, ... }:
{
  flake.hosts.spike = {
    ipv4 = [ "10.10.10.20" ];
    ipv6 = [ "2001:5a8:608c:4a00::20/64" ];
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
    public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO0xBpnsFa3YGevrl2vrSVL31nFtlgYb/7b+hmST3Vsz";
    facts = ./facter.json;
    nixosConfiguration = {
      # Enable NetworkManager for managing network interfaces
      networking.networkmanager.enable = true;
    };
  };
}
