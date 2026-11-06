{
  den.aspects.applications.dev.git.mergiraf = {
    homeManager = {
      programs.mergiraf = {
        enable = true;
        enableGitIntegration = true;
        enableJujutsuIntegration = true;
      };
    };

    cacheHome.directories = [
      ".local/share/mergiraf"
    ];
  };
}
