{ config, ... }:
{
  flake.hosts.bitstream = {
    deployment.targetHost = "10.10.10.5";
    roles = [
      "server"
    ];
    extra_modules = with config.flake.modules.nixos; [
      ./_local
      cpu-amd
      gpu-amd
    ];
    public_key = ./ssh_host_ed25519_key.pub;
    facts = ./facter.json;
  };
}
