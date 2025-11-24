{ ... }:
{
  flake.features.home-manager.nixos =
    {
      inputs,
      hostOptions,
      activeFeatures,
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
          inherit
            inputs
            hostOptions
            activeFeatures
            pkgs
            ;
          hasGlobalPkgs = true;
        };

        sharedModules = [
          (
            { osConfig, ... }:
            {
              # TODO: Fix this to support nix-darwin which uses a different stateVersion and homeDirectory
              home.stateVersion = osConfig.system.stateVersion;
              systemd.user.startServices = "sd-switch";
              # Home Manager manages itself
              programs.home-manager.enable = true;
            }
          )
        ];

        # User configurations are handled in nixos-configurations.nix
        # via the makeHome function which is feature-aware and handles
        # host features, user features, and user configurations properly.
      };
    };
}
