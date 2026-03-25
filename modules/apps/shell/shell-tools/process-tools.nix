{
  features.process-tools.home =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        procs
        mprocs
      ];
      programs.htop.enable = true;
    };
}
