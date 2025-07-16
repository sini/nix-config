{ config, ... }:
{
  flake.hosts.axon-03 = {
    deployment.targetHost = "10.10.10.4";
    roles = [
      "server"
      "kubernetes"
    ];
    extra_modules = with config.flake.modules.nixos; [
      disk-longhorn
      cpu-amd
      gpu-amd
    ];
    public_key = ./ssh_host_ed25519_key.pub;
    facts = ./facter.json;
  };
}
