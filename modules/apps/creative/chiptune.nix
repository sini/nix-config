{
  features.chiptune.home =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        alda
        lenmus
        milkytracker
        famistudio
        furnace
      ];
    };
}
