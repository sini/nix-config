_: {
  den.aspects.apps.shell.process = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.procs
          pkgs.mprocs
          pkgs.ctop
        ];

        programs.htop.enable = true;
      };
  };
}
