{
  features.home-manager.system =
    {
      inputs,
      environment,
      flakeLib,
      host,
      users,
      pkgs,
      ...
    }:
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = ".hm-backup";

        extraSpecialArgs = {
          inherit
            inputs
            environment
            flakeLib
            host
            users
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

          # Inject resolved user object as `user` specialArg per-user
          (
            { config, users, ... }:
            {
              _module.args.user = users.${config.home.username} or { };
            }
          )
        ];
      };
    };
}
