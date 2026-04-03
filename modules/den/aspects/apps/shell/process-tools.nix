{ den, ... }:
{
  den.aspects.process-tools = den.lib.perUser {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          procs
          mprocs
        ];
        programs.htop.enable = true;
      };
  };
}
