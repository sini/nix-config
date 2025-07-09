{
  flake.modules.homeManager.ssh = {
    programs.ssh = {
      enable = true;
    };
  };
}
