{ den, ... }:
{
  den.aspects.core.default = {
    includes = with den.aspects; [
      core.nix
      core.nixpkgs
      core.systemd-boot
      core.i18n
      core.stateVersion
      core.systemd
      core.shell
      core.utils
      core.firmware
      core.security
      core.facter
      core.home-manager
      core.deterministic-uids
      core.sudo
      core.time
      core.ssd
      core.linux-kernel
      core.users
      apps.zsh
      networking
      network.openssh
    ];
  };
}
