{
  den.aspects.core.users.shell = {
    os = {
      programs.zsh = {
        enable = true;
        enableCompletion = true;
      };
    };

    nixos =
      { pkgs, ... }:
      {
        environment.enableAllTerminfo = true;
        users.users.root.shell = pkgs.bashInteractive;
        users.defaultUserShell = pkgs.zsh;
      };
  };
}
