{
  flake.modules.homeManager.zsh.programs.zsh = {
    enable = true;
    syntaxHighlighting = {
      enable = true;
      highlighters = [
        "main"
        "brackets"
        "pattern"
        "regexp"
        "cursor"
        "line"
      ];
    };
  };
}
