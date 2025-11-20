{
  flake.features.easyeffects = {
    nixos = {
      # Technically not easyeffects, but we want it on the same systems
      programs.noisetorch.enable = true;
    };

    home =
      { lib, ... }:
      {
        services.easyeffects.enable = true;

        systemd.user.services.easyeffects = {
          Unit.Requisite = [ "graphical-session.target" ];
          Install.WantedBy = lib.mkForce [ ];
        };

        xdg.configFile = {
          "easyeffects/input/improved-microphone.json".source = ./presets/ImprovedMicrophone.json;
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
