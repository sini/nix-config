{
  flake.features.easyeffects = {
    nixos =
      { pkgs, ... }:
      {
        environment.systemPackages = with pkgs; [
          easyeffects
        ];
      };

    home = {
      xdg.configFile = {
        "easyeffects/output/HD650-Harmon.json".source = ./presets/HD650-Harmon.json;
        "easyeffects/output/HD6XX.json".source = ./presets/HD6XX.json;
        "easyeffects/output/GalaxyBuds.json".source = ./presets/GalaxyBuds.json;
      };

      home.persistence."/persist" = {
        directories = [
          ".config/easyeffects"
        ];
      };
    };
  };
}
