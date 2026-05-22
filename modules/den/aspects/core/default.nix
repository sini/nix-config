{ den, ... }:
{
  den.aspects.core.default = {
    includes = with den.aspects.core; [
      nix
      nixpkgs
      systemd-boot
      i18n
      stateVersion
      systemd
      shell
      utils
      firmware
      security
      facter
      home-manager
      deterministic-uids
      sudo
      time
      ssd
      linux-kernel
    ];
  };
}
