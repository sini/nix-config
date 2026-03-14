{
  writeShellApplication,
  age,
  age-plugin-yubikey,
  openssh,
  openssl,
  jq,
  nix,
  coreutils,
  git,
  agenix-rekey,
  clevis-minimal,
}:
writeShellApplication {
  name = "nix-flake-provision-keys";
  meta.description = "Provision SSH host keys and disk encryption secrets for a NixOS host";

  runtimeInputs = [
    age
    age-plugin-yubikey
    openssh
    openssl
    jq
    nix
    coreutils
    git
    agenix-rekey
    clevis-minimal
  ];
  text = builtins.readFile ./nix-flake-provision-keys.sh;
}
