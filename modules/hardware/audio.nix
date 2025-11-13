{
  flake.features.audio = {
    nixos =
      { pkgs, lib, ... }:
      {
        security.rtkit.enable = true;
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

            extraConfig.pipewire."92-low-latency" = {
              "context.properties" = {
                "default.clock.quantum" = 512;
                "default.clock.min-quantum" = 512;
                "default.clock.max-quantum" = 2048;
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
          #pavucontrol
          pwvucontrol
          coppwr
          qpwgraph # More extensive patchbay for Pipewire

          openal
          pulseaudio

          yabridge
          yabridgectl

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
