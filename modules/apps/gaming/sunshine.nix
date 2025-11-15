{ config, ... }:
let
  username = config.flake.meta.user.username;
in
{
  flake.features.sunshine = {
    nixos =
      { pkgs, ... }:
      {
        networking = {
          firewall = {
            allowedUDPPorts = [
              # Moonlight
              5353
              47998
              47999
              48000
              48002
              48010
            ];
            allowedTCPPorts = [
              # MoonDeck Buddy
              59999
              # Moonlight
              47984
              47989
              48010
            ];
          };
        };

        services.sunshine = {
          enable = true;
          # package = pkgs.sunshine.override { cudaSupport = true; };
          autoStart = true;
          capSysAdmin = true;
          openFirewall = true;
          applications = {
            env = {
              PATH = "$(PATH):/run/current-system/sw/bin:/etc/profiles/per-user/${username}/bin:$(HOME)/.local/bin";
            };
            apps = [
              {
                name = "Desktop";
                image-path = "desktop.png";
              }
              {
                name = "MoonDeckStream";
                cmd = "${pkgs.local.moondeck-buddy}/bin/MoonDeckStream";
                exclude-global-prep-cmd = "false";
                elevated = "false";
              }
              {
                name = "Steam Big Picture";
                image-path = "steam.png";
                detached = [ "${pkgs.util-linux}/bin/setsid ${pkgs.steam}/bin/steam steam://open/bigpicture" ];
                auto-detach = "true";
                wait-all = "true";
                exit-timeout = "5";
              }
            ];
          };
          settings = {
            adapter_name = "/dev/dri/renderD128";
            origin_web_ui_allowed = "lan";
            capture = "kms";
            encoder = "vaapi";
            output_name = 0;
          };
        };

        services.udev.extraRules = ''
          SUBSYSTEM=="misc", KERNEL=="uhid", GROUP="uinput", MODE="0660"
          SUBSYSTEMS=="input", ATTRS{name}=="Sunshine * (virtual) pad*", OWNER="sini"
          SUBSYSTEMS=="input", ATTRS{id/vendor}=="beef", ATTRS{id/product}=="dead", ATTRS{name}=="* passthrough*", OWNER="sini"
        '';
        # services.udev.extraRules = ''
        #   KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
        #   KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", TAG+="uaccess"
        # '';
      };

    home =
      { pkgs, ... }:
      {
        home.packages = with pkgs.local; [ moondeck-buddy ];
        xdg.autostart.entries = [ "${pkgs.local.moondeck-buddy}/share/applications/MoonDeckBuddy.desktop" ];
        home.persistence."/persist".directories = [
          ".config/sunshine/"
        ];
      };
  };
}
