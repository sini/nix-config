{ den, ... }:
{
  den.aspects.search-tools = den.lib.perUser {
    homeManager = {
      programs = {
        fd = {
          enable = true;
          hidden = true;
          ignores = [
            ".Trash"
            ".git"
            "**/node_modules"
            "**/target"
          ];
          extraOptions = [ "--no-ignore-vcs" ];
        };
        fzf = {
          enable = true;
          enableBashIntegration = true;
          enableFishIntegration = true;
          enableZshIntegration = true;
        };
        ripgrep = {
          enable = true;
          arguments = [
            "--smart-case"
            "--no-line-number"
            "--hidden"
            "--glob=!.git/*"
            "--max-columns=150"
            "--max-columns-preview"
          ];
        };
        skim.enable = true;
      };
    };
  };
}
