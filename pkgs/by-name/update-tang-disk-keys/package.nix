{
  writeShellApplication,
  age,
  age-plugin-yubikey,
  openssh,
  nix,
  jq,
  coreutils,
  git,
  clevis-minimal,
}:
writeShellApplication {
  name = "update-tang-disk-keys";
  meta.description = "Re-encrypt disk passphrase with TPM2 + Tang on a running host";
  runtimeInputs = [
    age
    age-plugin-yubikey
    openssh
    nix
    jq
    coreutils
    git
    clevis-minimal
  ];
  text = builtins.readFile ./update-tang-disk-keys.sh;
}
