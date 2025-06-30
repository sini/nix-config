{
  flake.modules = {
    nixos.shell =
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
