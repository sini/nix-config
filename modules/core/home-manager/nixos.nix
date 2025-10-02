{ ... }:
{
  flake.features.home-manager.nixos =
    {
      inputs,
      hostOptions,
      users,
      lib,
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

        users =
          let
            # Users are already filtered in specialArgs, so we generate configs for all of them
            enabledUsers = builtins.attrNames users;

            # Create home-manager user configurations for each enabled user
            userConfigs = lib.genAttrs enabledUsers (
              userName:
              let
                userHomeModules = users.${userName}.homeModules or [ ];
              in
              {
                home = {
                  username = userName;
                  homeDirectory = "/home/${userName}";
                };
                imports = userHomeModules;
              }
            );
          in
          userConfigs;
      };
    };
}
