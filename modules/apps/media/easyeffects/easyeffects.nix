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
          pkgs.at-spi2-core
          pkgs.easyeffects
        ];

        # services.easyeffects.enable = true;

        # systemd.user.services.easyeffects = {
        #   Service.ExecStart = lib.mkForce "${pkgs.easyeffects}/bin/easyeffects --service-mode --hide-window";
        # };
        # systemd.user.services.easyeffects = {
        #   Unit = {
        #     Description = "Easyeffects daemon";
        #     Requires = [ "dbus.service" ];
        #     After = [ "graphical-session-pre.target" ];
        #     ConditionEnvironment = "WAYLAND_DISPLAY";
        #     PartOf = [
        #       "graphical-session.target"
        #       "pipewire.service"
        #     ];
        #   };

        #   Install.WantedBy = [ "graphical-session.target" ];

        #   Service = {
        #     ExecStart = "${pkgs.easyeffects}/bin/easyeffects --service-mode --hide-window";
        #     ExecStop = "${pkgs.easyeffects}/bin/easyeffects --quit";
        #     Restart = "on-failure";
        #     RestartSec = 5;
        #   };
        # };
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
            Slice = "background.slice";
            Type = "simple";
            ExecStart = "${pkgs.easyeffects}/bin/easyeffects --service-mode --hide-window";
            ExecStop = "${pkgs.easyeffects}/bin/easyeffects --quit";
            Restart = "on-failure";
            KillMode = "mixed";
            RestartSec = 5;
            TimeoutStopSec = 10;
            # ExecStartPost = [
            #   "${lib.getExe config.services.easyeffects.package} --load-preset ${config.services.easyeffects.preset}"
            # ];
          };
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
