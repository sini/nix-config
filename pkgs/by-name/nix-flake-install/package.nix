{
  writeShellApplication,
  callPackage,
  age,
  age-plugin-yubikey,
  openssh,
  openssl,
  jq,
  nix,
  coreutils,
  findutils,
  nixos-anywhere,
  git,
  agenix-rekey,
}:
let
  nix-flake-provision-keys = callPackage ../nix-flake-provision-keys/package.nix { };
in
writeShellApplication {
  name = "nix-flake-install";
  meta.description = "Install NixOS remotely using nixos-anywhere with automated provisioning";
  runtimeInputs = [
    nix-flake-provision-keys
    age
    age-plugin-yubikey
    openssh
    openssl
    jq
    nix
    coreutils
    findutils
    nixos-anywhere
    git
    agenix-rekey
  ];
  text = builtins.readFile ./nix-flake-install.sh;
}
