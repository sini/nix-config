{ config, ... }:
{
  flake.hosts.spike = {
    ipv4 = "10.10.10.20";
    roles = [
      "workstation"
      "laptop"
      "gaming"
    ];
    extra_modules = with config.flake.modules.nixos; [
      ./_local
      cpu-intel
      gpu-intel
      gpu-nvidia
      gpu-nvidia-prime
      razer
    ];
    public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO0xBpnsFa3YGevrl2vrSVL31nFtlgYb/7b+hmST3Vsz root@spike";
    facts = ./facter.json;
  };
}
