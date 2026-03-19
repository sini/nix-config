{
  features.shell = {
    system = {
      programs.zsh = {
        enable = true;
        enableCompletion = true;
      };
    };

    linux =
      { pkgs, ... }:
      {
        users.defaultUserShell = pkgs.zsh;
      };
  };
}
