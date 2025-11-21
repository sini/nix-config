{
  flake.features.easyeffects = {
    nixos = {
      # Technically not easyeffects, but we want it on the same systems
      programs.noisetorch.enable = true;
    };

    home =
      { lib, pkgs, ... }:
      {
        home.packages = [
          pkgs.easyeffects
        ];

        systemd.user.services.easyeffects = {
          Unit = {
            After = lib.mkForce [
              "pipewire.service"
              "graphical-session.target"
            ];
            BindsTo = lib.mkForce [
              "pipewire.service"
              "graphical-session.target"
            ];
            PartOf = lib.mkForce [ ];
          };

          Install.WantedBy = lib.mkForce [ "pipewire.service" ];

          Service = {
            Slice = "session-graphical.slice";
            ExecStart = "${pkgs.easyeffects}/bin/easyeffects --service-mode --hide-window";
            ExecStop = "${pkgs.easyeffects}/bin/easyeffects --quit";
            Restart = "on-failure";
            RestartSec = 5;
            TimeoutStopSec = 10;
          };
        };

        xdg.dataFile = {
          "easyeffects/input/improved-microphone.json".source = ./presets/ImprovedMicrophone.json;
          "easyeffects/output/HD650-Harmon.json".source = ./presets/HD650-Harmon.json;
          "easyeffects/output/HD6XX.json".source = ./presets/HD6XX.json;
          "easyeffects/output/GalaxyBuds.json".source = ./presets/GalaxyBuds.json;
        };

        home.persistence."/persist" = {
          directories = [
            ".local/share/easyeffects"
          ];
        };
      };
  };
}
