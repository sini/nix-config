{ den, ... }:
{
  den.aspects.roles.default = {
    includes = with den.aspects; [
      core.nix
      core.nix.nixpkgs
      core.systemd.boot
      core.localization.i18n
      core.nix.stateVersion
      core.systemd
      core.users.shell
      core.utils
      core.system.firmware
      core.security
      core.system.facter
      core.users.home-manager
      core.users.deterministic-uids
      core.nix.remote-build-client
      core.security.sudo
      core.localization.time
      core.perf.disable-docs
      core.perf.ssd
      core.perf.zram-swap
      core.system.linux-kernel
      core.users

      core.impermanence

      apps.shell.zsh

      core.network.networking
      core.security.openssh
      core.network.hosts
      core.network.tailscale

      secrets.agenix
    ];
  };
}
