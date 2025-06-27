{
  flake.hosts.axon-02 = {
    deployment.targetHost = "10.10.10.3";
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
