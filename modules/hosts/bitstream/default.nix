{ config, ... }:
{
  flake.hosts.bitstream = {
    deployment.targetHost = "10.10.10.5";
    tags = [
      "server"
    ];
    extra_modules = with config.flake.modules.nixos; [
      media-data-share
      ./_local
    ];
    public_key = ./ssh_host_ed25519_key.pub;
    facts = ./facter.json;
  };
}
