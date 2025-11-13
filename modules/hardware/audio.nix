{
  flake.features.audio = {
    nixos =
      { pkgs, lib, ... }:
      {
        security.rtkit.enable = true;

        # services.pipewire.wireplumber.extraConfig = {
        #   "10-disable-camera.conf" = {
        #     "wireplumber.profiles".main."monitor.libcamera" = "disabled";
        #   };

        #   "60-dac-priority" = {
        #     "monitor.alsa.rules" = [
        #       {
        #         matches = [
        #           {
        #             "node.name" = "alsa_input.usb-Focusrite_Scarlett_2i2_USB_Y80HQQ415BC300-00.HiFi__Mic1__source";
        #           }
        #           {
        #             "node.name" = "alsa_output.usb-Focusrite_Scarlett_2i2_USB_Y80HQQ415BC300-00.HiFi__Line1__sink";
        #           }
        #         ];
        #         actions = {
        #           update-props = {
        #             # normal input priority is sequential starting at 2000
        #             "priority.driver" = "3000";
        #             "priority.session" = "3000";
        #           };
        #         };
        #       }
        #     ];
        #   };
        # };

        # https://another.maple4ever.net/archives/2994/
        boot.extraModprobeConfig = ''
          options snd_usb_audio vid=0x1235 pid=0x8210 device_setup=1 quirk_flags=0x1
        '';

        services.pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          wireplumber.enable = true;
          jack.enable = true;
          pulse.enable = true;

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

            alsa-monitor = {
              properties = {
                "alsa.use-acp" = false;
                "alsa.midi" = false; # Disable if not needed
                # Better hardware parameter handling
                "api.alsa.period-size" = 512;
                "api.alsa.period-num" = 2;
                "api.alsa.headroom" = 1024;
                # Disable hardware mixing for pure output
                "api.alsa.disable-mmap" = false;
                "api.alsa.use-chmap" = false;
              };
            };
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
                "default.clock.rate" = 96000;
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

            pipewire."99-disable-acp-global" = {
              "context.properties" = {
                "alsa.use-acp" = false;
              };
            };

            # set higher pipewire quantum to fix issues with crackling sound
            pipewire."92-quantum" = {
              "context.properties" = {
                "default.clock.rate" = 48000;
                "default.clock.quantum" = 256;
                "default.clock.min-quantum" = 256;
                "default.clock.max-quantum" = 512;
              };
            };

            # also set the quantum for pipewire-pulse, this is often used by games
            pipewire-pulse."92-quantum" =
              let
                qr = "256/48000";
              in
              {
                "context.properties" = [
                  {
                    name = "libpipewire-module-protocol-pulse";
                    args = { };
                  }
                ];
                "pulse.properties" = {
                  "pulse.default.req" = qr;
                  "pulse.min.req" = qr;
                  "pulse.max.req" = qr;
                  "pulse.min.quantum" = qr;
                  "pulse.max.quantum" = qr;
                };
                "stream.properties" = {
                  "node.latency" = qr;
                };
              };
          };

        };

        # TODO: restore once cuda is fixed
        # programs.noisetorch.enable = true;

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
          easyeffects
          playerctl
          #pavucontrol
          pwvucontrol
          coppwr
          qpwgraph # More extensive patchbay for Pipewire

          openal
          pulseaudio

          yabridge
          yabridgectl
          beets

          vital
          odin2
          surge
          fire
          decent-sampler
          lsp-plugins
        ];
      };

    home = {
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
