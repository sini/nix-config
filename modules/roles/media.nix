{ config, ... }:
{
  flake.modules.nixos.role_media = {
    # imports = with config.flake.modules.nixos; [
    #   direnv
    #   vscode
    #   gpg
    # ];

    home-manager.users.${config.flake.meta.user.username}.imports =
      with config.flake.modules.homeManager; [
        media
        mpv
      ];
  };
}
