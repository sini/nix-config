{
  flake.features.shell = {
    nixos =
      { pkgs, ... }:
      {
        programs.zsh = {
          enable = true;
          enableCompletion = true;
        };

        users.defaultUserShell = pkgs.zsh;
      };
  };
}
