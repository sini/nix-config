{ config, ... }:
{
  flake.hosts.axon-02 = {
    ipv4 = "10.10.10.3";
    roles = [
      "server"
      "kubernetes"
    ];
    extra_modules = with config.flake.modules.nixos; [
      disk-longhorn
      cpu-amd
      gpu-amd
    ];
    tags = {
      "kubernetes-cluster" = "dev";
    };
    public_key = ./ssh_host_ed25519_key.pub;
    facts = ./facter.json;
  };
}
