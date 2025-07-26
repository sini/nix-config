{
  flake.modules = {
    nixos.direnv = {
      # Prevent garbage collection from altering nix-shells managed by nix-direnv
      # https://github.com/nix-community/nix-direnv#installation
      nix.settings = {
        keep-outputs = true;
        keep-derivations = true;
      };
    };

    homeManager.direnv =
      { config, ... }:
      {
        programs = {
          direnv = {
            enable = true;
            nix-direnv.enable = true;
            config.global.warn_timeout = 0;
            enableBashIntegration = true;
            enableZshIntegration = config.programs.zsh.enable;
            enableNushellIntegration = config.programs.nushell.enable;
          };

          git.ignores = [
            ".envrc"
            ".direnv"
          ];
        };
      };
  };
}
