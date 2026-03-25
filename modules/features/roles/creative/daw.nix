{
  features.daw.home =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        reaper
        ardour
        audacity
        sunvox
        supercollider
      ];
    };
}
