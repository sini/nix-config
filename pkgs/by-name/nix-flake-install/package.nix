{
  writeShellApplication,
  age,
  age-plugin-yubikey,
  openssh,
  openssl,
  jq,
  nix,
  coreutils,
  nixos-anywhere,
  git,
  agenix-rekey,
}:
writeShellApplication {
  name = "nix-flake-install";
  meta.description = "Install NixOS remotely using nixos-anywhere with automated provisioning";
  runtimeInputs = [
    age
    age-plugin-yubikey
    openssh
    openssl
    jq
    nix
    coreutils
    nixos-anywhere
    git
    agenix-rekey
  ];
  text = builtins.readFile ./nix-flake-install.sh;
}
