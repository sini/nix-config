{
  flake.role.core = {
    nixosModules = [
      "agenix"
      "avahi"
      "deterministic-uids"
      "disko"
      "facter"
      "firmware"
      "home-manager"
      "hosts"
      "i18n"
      "networking"
      "nix"
      "nixpkgs"
      "openssh"
      "power-mgmt"
      "shell"
      "ssd"
      "sudo"
      "systemd-boot"
      "time"
      "users"
      "utils"
      "zsh"
    ];

    homeManagerModules = [
      "starship"
      "zsh"
    ];
  };
}
