_: {
  den.aspects.apps.dev.eza = {
    homeManager = {
      programs.eza = {
        enable = true;
        enableBashIntegration = true;
        enableFishIntegration = true;
        enableZshIntegration = true;
        enableNushellIntegration = true;
        icons = "auto";
        git = true;
        extraOptions = [
          "--group-directories-first"
          "--header"
          "--all"
        ];
      };
    };
  };
}
