{ den, ... }:
let
  presetsDir = ../../../../apps/media/easyeffects/presets;
in
{
  den.aspects.easyeffects = {
    _ = {
      system = den.lib.perHost {
        nixos = {
          # Technically not easyeffects, but we want it on the same systems
          programs.noisetorch.enable = true;
        };
      };

      home = den.lib.perUser {
        homeManager = {
          services.easyeffects.enable = true;

          xdg.dataFile = {
            "easyeffects/input/improved-microphone.json".source = presetsDir + /ImprovedMicrophone.json;
            "easyeffects/output/HD650-Harmon.json".source = presetsDir + /HD650-Harmon.json;
            "easyeffects/output/HD6XX.json".source = presetsDir + /HD6XX.json;
            "easyeffects/output/GalaxyBuds.json".source = presetsDir + /GalaxyBuds.json;
          };
        };

        persistHome.directories = [
          ".local/share/easyeffects"
        ];
      };
    };
  };
}
