{ config, ... }:
{
  flake.modules.nixos.role_core = {
    imports = with config.flake.modules.nixos; [
      agenix
      avahi
      deterministic-uids
      disko
      facter
      firmware
      home-manager
      homelab
      i18n
      networking
      nix
      nixpkgs
      openssh
      power-mgmt
      shell
      ssd
      sudo
      systemd-boot
      time
      users
      utils
      zsh
    ];

    home-manager.users.${config.flake.meta.user.username}.imports =
      with config.flake.modules.homeManager; [
        starship
        zsh
      ];
  };
}
