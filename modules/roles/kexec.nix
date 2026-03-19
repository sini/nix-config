{
  roles.kexec = {
    features = [
      "agenix"
      "deterministic-uids"
      "disko"
      "facter"
      "kexec"
      "impermanence" # Disabled in kexec
      "networking"
      "nix"
      "nixpkgs"
      "openssh"
      "security"
      "sudo"
      "systemd"
      "users"
      "utils"
    ];
  };
}
