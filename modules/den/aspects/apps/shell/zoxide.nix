{ den, ... }:
{
  den.aspects.zoxide = den.lib.perUser {
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
