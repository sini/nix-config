{
  flake.modules = {
    nixos.shell = {
      # Prevent garbage collection from altering nix-shells managed by nix-direnv
      # https://github.com/nix-community/nix-direnv#installation
      nix.settings = {
        keep-outputs = true;
        keep-derivations = true;
      };
    };

    homeManager.shell = {
      programs = {
        direnv = {
          enable = true;
          config = {
            global = {
              hide_env_diff = true;
            };
          };
          nix-direnv.enable = true;
        };
      };
    };
  };
}
