{
  features.gh.home = _: {
    programs.gh = {
      enable = true;
      settings = {
        git_protocol = "ssh";
      };
    };
  };
}
