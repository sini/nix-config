{
  config,
  ...
}:
{
  flake.modules.nixos.home-manager =
    { inputs, hostConfig, ... }:
    {
      # home-manager is defined in nixos-configurations for all machines
      # which lets us switch the version used for stable, unstable, and
      # darwin hosts.
      # imports = [ inputs.home-manager.nixosModules.home-manager ];

      home-manager = {
        useGlobalPkgs = true;

        extraSpecialArgs = {
          inherit inputs hostConfig;
          hasGlobalPkgs = true;
        };

        users.${config.flake.meta.user.username}.imports = [
          (
            { osConfig, ... }:
            {
              # TODO: Fix this to support nix-darwin
              home.stateVersion = osConfig.system.stateVersion;
            }
          )
          # config.flake.modules.homeManager.core
          # config.flake.modules.homeManager.gui
        ];
      };
    };
}
