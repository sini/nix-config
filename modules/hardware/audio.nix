{
  flake.features.audio = {
    nixos =
      {
        pkgs,
        lib,
        ...
      }:
      {
        # imports = [
        #   inputs.nix-gaming.nixosModules.pipewireLowLatency
        # ];

        security.rtkit.enable = true;
        services.pulseaudio.enable = lib.mkForce false; # disable pulseAudio
        services.pipewire = {
          enable = true;
          alsa = {
            enable = true;
            support32Bit = true;
          };
          wireplumber.enable = true;
          jack.enable = true;
          pulse.enable = true;

          # lowLatency = {
          #   enable = true;
          #   quantum = 64;
          #   rate = 96000;
          # };

          wireplumber.extraConfig = {
            # Enable Fancy Blueooth Codecs
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

            # alsa-monitor = {
            #   properties = {
            #     # "alsa.use-acp" = false;
            #     "alsa.midi" = false; # Disable if not needed
            #     # Better hardware parameter handling
            #     "api.alsa.period-size" = 512;
            #     "api.alsa.period-num" = 2;
            #     "api.alsa.headroom" = 1024;
            #     # Disable hardware mixing for pure output
            #     "api.alsa.disable-mmap" = false;
            #     "api.alsa.use-chmap" = false;
            #   };
            # };
          };

          extraConfig = {
            client."10-resample" = {
              "stream.properties" = {
                "resample.quality" = 10;
              };
            };

            # Up-to 192kHz in the Focusrite
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

            # pipewire."99-disable-acp-global" = {
            #   "context.properties" = {
            #     "alsa.use-ucm" = true;
            #   };
            # };
          };

        };

        # https://github.com/hlissner/dotfiles/blob/b51c0d90673a3f3779197ca53952bfe85718f708/modules/desktop/media/daw.nix
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

        environment.systemPackages = with pkgs; [
          # Audio related packages
          alsa-utils
          playerctl
          pavucontrol
          pwvucontrol
          paprefs
          pulsemixer
          cava

          coppwr
          qpwgraph # More extensive patchbay for Pipewire

          openal
          pulseaudio

          #yabridge # TODO: re-enable when fixed upstream
          #yabridgectl
          beets

          # VST stuff
          vital
          odin2
          # surge # TODO: Re-enable
          fire
          decent-sampler
          lsp-plugins
        ];
      };

    home =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.wiremix
        ];
        home.persistence."/persist" = {
          directories = [
            ".local/state/wireplumber" # Wireplumber state
            ".config/rncbc.org" # qpwgraph config file
            ".config/pulse" # pulseaudio cookie
          ];
        };
      };
  };
}
