{ den, ... }:
{
  den.aspects.default = {
    includes = [
      den.aspects.agenix
      den.aspects.avahi
      den.aspects.deterministic-uids
      den.aspects.disko
      den.aspects.facter
      den.aspects.firmware
      den.aspects.home-manager-feature
      den.aspects.hosts-file
      den.aspects.i18n
      den.aspects.impermanence
      den.aspects.linux-kernel
      den.aspects.networking
      den.aspects.nix
      den.aspects.nixpkgs
      den.aspects.openssh
      den.aspects.power-mgmt
      den.aspects.security
      den.aspects.shell
      den.aspects.ssd
      den.aspects.stateVersion
      den.aspects.sudo
      den.aspects.systemd
      den.aspects.systemd-boot
      den.aspects.tailscale
      den.aspects.time
      den.aspects.users
      den.aspects.utils
    ];
  };
}
