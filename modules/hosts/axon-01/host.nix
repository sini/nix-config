{ config, ... }:
{
  flake.hosts.axon-01 = {
    deployment.targetHost = "10.10.10.2";
    roles = [
      "server"
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
