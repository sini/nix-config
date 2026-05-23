_: {
  den.aspects.apps.zoxide = {
    homeManager = {
      programs.zoxide = {
        enable = true;
        enableBashIntegration = true;
        enableFishIntegration = true;
        enableNushellIntegration = true;
        enableZshIntegration = true;
        options = [
          "--cmd"
          "cd"
        ];
      };
    };
  };
}
