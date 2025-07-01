{
  config,
  inputs,
  ...
}:
{
  flake.modules.nixos.home-manager = {
    imports = [ inputs.home-manager.nixosModules.home-manager ];

    home-manager = {
      useGlobalPkgs = true;
      extraSpecialArgs.hasGlobalPkgs = true;

      users.${config.flake.meta.user.username}.imports = [
        (
          { osConfig, ... }:
          {
            # TODO: Fix this to support nix-darwin
            home.stateVersion = osConfig.system.stateVersion;
          }
        )
        config.flake.modules.homeManager.core
        # config.flake.modules.homeManager.gui
      ];
    };
  };
}
