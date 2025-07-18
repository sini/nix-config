{ config, ... }:
{
  flake.hosts.uplink = {
    deployment.targetHost = "10.10.10.1";
    roles = [
      "server"
    ];
    extra_modules = with config.flake.modules.nixos; [
      ./_local
      cpu-amd
      gpu-intel
      disk-single
      podman
    ];
    public_key = ./ssh_host_ed25519_key.pub;
    facts = ./facter.json;
  };
}
