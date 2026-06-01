{ den, ... }:
{
  den.aspects.roles.default = {
    includes = with den.aspects; [
      core.nix
      core.lix
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
      core.nix-remote-build-client
      core.sudo
      core.time
      core.ssd
      core.linux-kernel
      core.users

      disk.impermanence

      apps.zsh

      network.networking
      network.openssh
      network.hosts

      secrets.agenix

      services.tailscale
    ];
  };
}
