{
  writeShellApplication,
  age,
  openssh,
  jq,
  nix,
  coreutils,
}:
writeShellApplication {
  name = "update-host-keys";
  meta.description = "Collect and encrypt SSH host keys from all configured hosts";
  runtimeInputs = [
    age
    openssh
    jq
    nix
    coreutils
  ];
  text = builtins.readFile ./update-host-keys.sh;
}
