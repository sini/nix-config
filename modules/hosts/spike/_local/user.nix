{
  config,
  lib,
  ...
}:
{

  home-manager.users.sini = {
    imports = [
      ../../../../hm/core.nix
    ];
    home.stateVersion = lib.mkDefault config.system.stateVersion;
  };

}
