{
  den.aspects.roles.creative.daw = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.reaper
          pkgs.ardour
          pkgs.audacity
          pkgs.sunvox
          pkgs.supercollider
        ];
      };

    persistHome.directories = [
      ".config/REAPER"
      ".config/audacity"
      ".local/share/audacity"
      ".config/DecentSampler"
    ];
  };
}
