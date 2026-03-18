{
  flake.features.home-manager.system =
    {
      inputs,
      environment,
      host,
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
            environment
            host
            pkgs
            ;
          hasGlobalPkgs = true;
        };

        sharedModules = [
          (
            { osConfig, lib, ... }:
            {
              # On NixOS, system.stateVersion is a string (e.g. "25.05") matching HM format.
              # On nix-darwin, it's an integer (e.g. 6) which HM can't use.
              home.stateVersion =
                if pkgs.stdenv.isLinux then osConfig.system.stateVersion else lib.trivial.release;
              programs.home-manager.enable = true;
            }
            // lib.optionalAttrs pkgs.stdenv.isLinux {
              systemd.user.startServices = "sd-switch";
            }
          )
        ];

        # User configurations are handled in nixos-configurations.nix
        # via the makeHome function which is feature-aware and handles
        # host features, user features, and user configurations properly.
      };
    };
}
