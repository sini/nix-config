{ config, ... }:
{
  flake.hosts.spike = {
    unstable = true;
    deployment.targetHost = "10.10.10.20";
    roles = [
      "workstation"
      "laptop"
    ];
    extra_modules = with config.flake.modules.nixos; [
      ./_local
      cpu-intel
      gpu-intel
      gpu-nvidia
      gpu-nvidia-prime
    ];
    public_key = ./ssh_host_ed25519_key.pub;
    facts = ./facter.json;
  };
}
