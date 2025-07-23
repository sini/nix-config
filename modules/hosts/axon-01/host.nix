{ config, ... }:
{
  flake.hosts.axon-01 = {
    ipv4 = "10.10.10.2";
    roles = [
      "server"
      "kubernetes"
      "kubernetes-master"
    ];
    extra_modules = with config.flake.modules.nixos; [
      disk-longhorn
      cpu-amd
      gpu-amd
    ];
    tags = {
      "kubernetes-cluster" = "dev";
      "kubernetes-master" = "true";
    };
    public_key = ./ssh_host_ed25519_key.pub;
    facts = ./facter.json;
  };
}
