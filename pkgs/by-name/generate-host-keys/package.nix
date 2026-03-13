{
  writeShellApplication,
  age,
  openssh,
  coreutils,
}:
writeShellApplication {
  name = "generate-host-keys";
  meta.description = "Generate and encrypt SSH host keys for a new host";
  runtimeInputs = [
    age
    openssh
    coreutils
  ];
  text = builtins.readFile ./generate-host-keys.sh;
}
