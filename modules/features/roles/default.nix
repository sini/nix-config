{
  # Default features that provide essential system functionality
  # This replaces the old "core" role and ensures every host has basic capabilities
  features.default = {
    requires = [
      "agenix"
      "avahi"
      "deterministic-uids"
      "disko"
      "facter"
      "firmware"
      "home-manager"
      "hosts"
      "i18n"
      "impermanence"
      "linux-kernel"
      "networking"
      "nix"
      "nixpkgs"
      "openssh"
      "power-mgmt"
      "security"
      "shell"
      "ssd"
      "stateVersion"
      "sudo"
      "systemd"
      "systemd-boot"
      "tailscale"
      "time"
      "users"
      "utils"
      "zsh"
    ];
  };
}
