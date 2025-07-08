{
  flake.modules.homeManager.core.programs.zsh = {
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
