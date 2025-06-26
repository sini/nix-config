_: {
  flake.hosts.spike = {
    unstable = true;
    deployment.targetHost = "10.10.10.20";
    deployment.remoteBuild = true;
    tags = [
      "core"
      "workstation"
      "laptop"
    ];
    public_key = ../../../systems/x86_64-linux/spike/ssh_host_ed25519_key.pub;
    facts = ../../../systems/x86_64-linux/spike/facter.json;
    root_path = ../../../systems/x86_64-linux/spike;
  };
}
