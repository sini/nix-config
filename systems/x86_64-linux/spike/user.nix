{
  config,
  lib,
  ...
}:
{

  home-manager.users.sini = {
    imports = [
      ../../hm/core.nix
    ];

    programs.nixos-rebuild-and-notify.enable = true;

    home.stateVersion = lib.mkDefault config.system.stateVersion;
  };

}
