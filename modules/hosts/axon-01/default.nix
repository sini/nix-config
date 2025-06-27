_: {
  flake.hosts.axon-01 = {
    deployment.targetHost = "10.10.10.2";
    tags = [
      "server"
    ];
    additional_modules = [
      ./_local
    ];
    public_key = ./ssh_host_ed25519_key.pub;
    facts = ./facter.json;
  };
}
