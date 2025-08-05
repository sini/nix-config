{
  config,
  ...
}:
{
  flake.modules.nixos.home-manager =
    {
      inputs,
      hostOptions,
      pkgs,
      ...
    }:
    {
      # home-manager is defined in nixos-configurations for all machines
      # which lets us switch the version used for stable, unstable, and
      # darwin hosts.
      # imports = [ inputs.home-manager.nixosModules.home-manager ];

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = ".hm-backup";

        extraSpecialArgs = {
          inherit inputs hostOptions pkgs;
          hasGlobalPkgs = true;
        };

        users.${config.flake.meta.user.username}.imports = [
          (
            { osConfig, ... }:
            {
              # TODO: Fix this to support nix-darwin which uses a different stateVersion and homeDirectory
              home = {
                stateVersion = osConfig.system.stateVersion;
                username = "${config.flake.meta.user.username}";
                homeDirectory = "/home/${config.flake.meta.user.username}";
              };
              systemd.user.startServices = "sd-switch";
              # Home Manager manages itself
              programs.home-manager.enable = true;
            }
          )
        ];
      };
    };
}
