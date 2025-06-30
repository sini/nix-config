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
    ];
    public_key = ./ssh_host_ed25519_key.pub;
    facts = ./facter.json;
  };
}
