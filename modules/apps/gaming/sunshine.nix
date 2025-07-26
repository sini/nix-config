{ config, ... }:
let
  username = config.flake.meta.user.username;
in
{
  flake.modules.nixos.sunshine =
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
              detached = [ "steam steam://open/bigpicture" ];
              auto-detach = "true";
              wait-all = "true";
              exit-timeout = "5";
            }
          ];
        };
        settings = {
          output_name = 1;
        };
      };

      home-manager.users.${username}.imports = with config.flake.modules.homeManager; [
        sunshine
      ];
    };

  flake.modules.homeManager.sunshine =
    { pkgs, ... }:
    {
      home.packages = with pkgs.local; [ moondeck-buddy ];
      xdg.autostart.entries = [ "${pkgs.local.moondeck-buddy}/share/applications/MoonDeckBuddy.desktop" ];
    };
}
