{ den, lib, ... }:
{
  den.aspects.pipewire = {
    # All sub-aspects are included when the generic 'pipewire' aspect is used
    includes = lib.attrValues den.aspects.pipewire._;

    _ = {
      # Core pipewire system configuration (NixOS only)
      nixos = den.lib.perHost {
        nixos =
          { pkgs, lib, ... }:
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
                # Enable Fancy Bluetooth Codecs
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

            environment.systemPackages = with pkgs; [
              alsa-utils
              playerctl
              pavucontrol
              pwvucontrol
              paprefs
              pulsemixer
              cava

              coppwr
              qpwgraph

              openal
              pulseaudio

              yabridge
              yabridgectl

              vital
              odin2
              fire
              decent-sampler
              lsp-plugins
            ];
          };
      };

      # Home-manager package for the user (Linux only)
      home = den.lib.perUser {
        homeLinux =
          { pkgs, ... }:
          {
            home.packages = [
              pkgs.wiremix
            ];
          };
      };

      # Provider: impermanence directories for wireplumber/pulse state
      impermanence = den.lib.perUser {
        homeLinux = {
          home.persistence."/persist".directories = [
            ".local/state/wireplumber"
            ".config/rncbc.org"
            ".config/pulse"
          ];
        };
      };
    };
  };
}
