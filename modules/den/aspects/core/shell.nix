{ den, ... }:
{
  den.aspects.core.shell = {
    nixos =
      { pkgs, ... }:
      {
        programs.zsh = {
          enable = true;
          enableCompletion = true;
        };

        users.defaultUserShell = pkgs.zsh;
        users.users.root.shell = pkgs.bashInteractive;

        environment.enableAllTerminfo = true;
      };
  };
}
