{ config, ... }:
{
  flake.modules.nixos.home-manager =
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

        sharedModules =
          let
            # Helper function to gather and deduplicate modules from core and host-specific roles.
            getModulesForRoles =
              { roleType, hostRoles }:
              let
                # e.g., "nixosModules" or "homeManagerModules"
                moduleAttrName = "${roleType}Modules";
                # e.g., config.flake.modules.nixos or config.flake.modules.homeManager
                modulePath = config.flake.modules.${roleType};

                # 1. Start with the core modules required for all systems.
                coreModules = config.flake.role.core.${moduleAttrName};

                # 2. Get modules from additional roles defined on the host.
                additionalModules = lib.optionals (hostRoles != null) (
                  lib.flatten (
                    builtins.map (roleName: config.flake.role.${roleName}.${moduleAttrName}) (
                      # Ensure the role actually exists before trying to access it.
                      lib.filter (roleName: lib.hasAttr roleName config.flake.role) hostRoles
                    )
                  )
                );

                # 3. Combine core and additional module names.
                allModuleNames = coreModules ++ additionalModules;

              in
              # 4. Remove duplicate names and map them to their actual module files.
              builtins.map (moduleName: modulePath.${moduleName}) (lib.unique allModuleNames);

            # Get home-manager modules from roles
            roleHomeModules = getModulesForRoles {
              roleType = "homeManager";
              hostRoles = hostOptions.roles;
            };
          in
          [
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
          ]
          ++ roleHomeModules;

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
