_: {
  den.aspects.core.users.shell = {
    os =
      { pkgs, ... }:
      {
        programs.zsh = {
          enable = true;
          enableCompletion = true;
        };

        users.users.root.shell = pkgs.bashInteractive;

        environment.enableAllTerminfo = true;
      };

    nixos =
      { pkgs, ... }:
      {
        users.defaultUserShell = pkgs.zsh;
      };
  };
}
