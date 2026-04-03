# Sunshine: game streaming server with Moonlight/MoonDeck support.
{ den, lib, ... }:
{
  den.aspects.sunshine = {
    includes = lib.attrValues den.aspects.sunshine._;

    _ = {
      config = den.lib.perHost (
        { host }:
        let
          username = host.system-owner;
        in
        {
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
                KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
                KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", TAG+="uaccess"
              '';
            };
        }
      );

      home = den.lib.perUser {
        homeManager =
          { pkgs, ... }:
          {
            home.packages = with pkgs.local; [ moondeck-buddy ];
            xdg.autostart.entries = [ "${pkgs.local.moondeck-buddy}/share/applications/MoonDeckBuddy.desktop" ];
          };
      };

      persist-home = den.lib.perUser {
        homeManager = {
          home.persistence."/persist".directories = [
            ".config/sunshine/"
          ];
        };
      };
    };
  };
}
