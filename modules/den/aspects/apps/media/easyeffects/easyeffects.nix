_: {
  den.aspects.apps.easyeffects = {
    nixos = {
      programs.noisetorch.enable = true;
    };

    homeManager = {
      services.easyeffects.enable = true;

      xdg.dataFile = {
        "easyeffects/input/improved-microphone.json".source = ./presets/ImprovedMicrophone.json;
        "easyeffects/output/HD650-Harmon.json".source = ./presets/HD650-Harmon.json;
        "easyeffects/output/HD6XX.json".source = ./presets/HD6XX.json;
        "easyeffects/output/GalaxyBuds.json".source = ./presets/GalaxyBuds.json;
      };
    };

    provides.impermanence = {
      homeManager = {
        home.persistence."/persist".directories = [
          ".local/share/easyeffects"
        ];
      };
    };
  };
}
