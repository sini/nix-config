{
  flake.aspects.audio.nixos =
    { pkgs, ... }:
    {
      # home-manager.users.sini.home.persistence."/persist/home/sini" = lib.mkIf config.home-manager.extraSpecialArgs.isImpermanent {
      #   directories = [
      #     ".local/state/wireplumber" # Wireplumber state
      #     ".config/rncbc.org" # qpwgraph config file
      #     ".config/pulse" # pulseaudio cookie
      #   ];
      # };

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
      programs.noisetorch.enable = true;

      environment.systemPackages = with pkgs; [
        # Audio related packages
        alsa-utils
        easyeffects
        pavucontrol
        qpwgraph # More extensive patchbay for Pipewire
      ];
    };
}
