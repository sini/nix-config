{ den, ... }:
{
  den.aspects.hardware.audio = {
    nixos =
      {
        pkgs,
        lib,
        ...
      }:
      {
        security.rtkit.enable = true;
        services.pulseaudio.enable = lib.mkForce false;
        services.pipewire = {
          enable = true;
          alsa = {
            enable = true;
            support32Bit = true;
          };
          wireplumber.enable = true;
          jack.enable = true;
          pulse.enable = true;

          wireplumber.extraConfig = {
            "monitor.bluez.properties" = {
              "bluez5.enable-sbc-xq" = true;
              "bluez5.enable-msbc" = true;
              "bluez5.enable-hw-volume" = true;
              "bluez5.roles" = [
                "hsp_hs"
                "hsp_ag"
                "hfp_hf"
                "hfp_ag"
              ];
            };
          };

          extraConfig = {
            client."10-resample" = {
              "stream.properties" = {
                "resample.quality" = 10;
              };
            };

            pipewire."99-playback-96khz" = {
              "context.properties" = {
                "default.clock.rate" = 48000;
                "default.clock.allowed-rates" = [
                  44100
                  48000
                  88200
                  96000
                  176400
                  192000
                ];
              };
            };
          };
        };

        environment.sessionVariables =
          let
            makePluginPath =
              format:
              "$HOME/.${format}:"
              + (lib.makeSearchPath format [
                "$HOME/.nix-profile/lib"
                "/run/current-system/sw/lib"
                "/etc/profiles/per-user/$USER/lib"
              ]);
          in
          {
            ALSOFT_DRIVERS = "pulse";

            DSSI_PATH = makePluginPath "dssi";
            LADSPA_PATH = makePluginPath "ladspa";
            LV2_PATH = makePluginPath "lv2";
            LXVST_PATH = makePluginPath "lxvst";
            VST_PATH = makePluginPath "vst";
            VST3_PATH = makePluginPath "vst3";
          };

        environment.systemPackages = [
          pkgs.alsa-utils
          pkgs.playerctl
          pkgs.pavucontrol
          pkgs.pwvucontrol
          pkgs.paprefs
          pkgs.pulsemixer
          pkgs.cava
          pkgs.coppwr
          pkgs.qpwgraph
          pkgs.openal
          pkgs.pulseaudio
          pkgs.yabridge
          pkgs.yabridgectl
          pkgs.vital
          pkgs.odin2
          pkgs.fire
          pkgs.decent-sampler
          pkgs.lsp-plugins
        ];
      };

    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.wiremix
        ];
      };

    persistHome = {
      directories = [
        ".local/state/wireplumber"
        ".config/rncbc.org"
        ".config/pulse"
      ];
    };
  };
}
