{ config, ... }:
{
  flake.hosts.axon-02 = {
    deployment.targetHost = "10.10.10.3";
    roles = [
      "server"
    ];
    extra_modules = with config.flake.modules.nixos; [
      ./_local
      cpu-amd
    ];
    public_key = ./ssh_host_ed25519_key.pub;
    facts = ./facter.json;
  };
}
