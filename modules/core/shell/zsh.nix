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

        # Stick to bash for root shell
        users.users.root.shell = pkgs.bashInteractive;
      };
  };
}
