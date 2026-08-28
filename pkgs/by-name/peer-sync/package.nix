{
  writeShellApplication,
  git,
  openssh,
  coreutils,
  gnugrep,
  gnused,
}:
writeShellApplication {
  name = "peer-sync";
  meta.description = "Mirror a host's git refs to a peer so in-flight work is transferable between machines";
  runtimeInputs = [
    git
    openssh
    coreutils
    gnugrep
    gnused
  ];
  text = builtins.readFile ./peer-sync.sh;
}
