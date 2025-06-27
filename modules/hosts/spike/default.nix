{
  flake.hosts.spike = {
    unstable = true;
    deployment.targetHost = "10.10.10.20";
    tags = [
      "workstation"
      "laptop"
    ];
    additional_modules = [
      ./_local
    ];
    public_key = ./ssh_host_ed25519_key.pub;
    facts = ./facter.json;
  };
}
