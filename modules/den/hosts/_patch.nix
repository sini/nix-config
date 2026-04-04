{
  den,
  inputs,
  rootPath,
  ...
}:
{
  den.hosts.aarch64-darwin.patch = {
    instantiate = inputs.nix-darwin.lib.darwinSystem;
    environment = "dev";
    system-access-groups = [ "system-access" ];
    public_key = rootPath + "/.secrets/hosts/patch/ssh_host_ed25519_key.pub";
  };

  den.aspects.patch = {
    includes = [
      den.aspects.default
      # Roles
      den.aspects.dev
    ];

    # Host-specific darwin config (from old systemConfiguration)
    nixos =
      { lib, ... }:
      {
        # Darwin uid override (macOS uses 501 instead of 1000)
        users.users.sini.uid = lib.mkForce 501;

        # Touch ID for sudo
        security.pam.services.sudo_local.touchIdAuth = true;

        system = {
          primaryUser = "sini";

          defaults = {
            NSGlobalDomain = {
              ApplePressAndHoldEnabled = false;
              AppleShowAllExtensions = true;
              NSAutomaticCapitalizationEnabled = false;
              NSAutomaticPeriodSubstitutionEnabled = false;
              NSAutomaticSpellingCorrectionEnabled = false;
              NSWindowShouldDragOnGesture = true;
              InitialKeyRepeat = 15;
              KeyRepeat = 2;
              "com.apple.keyboard.fnState" = true;
              "com.apple.mouse.tapBehavior" = 1;
              "com.apple.sound.beep.volume" = 0.0;
              "com.apple.sound.beep.feedback" = 0;
            };

            dock = {
              autohide = true;
              show-recents = false;
              launchanim = true;
              mouse-over-hilite-stack = true;
              orientation = "bottom";
              tilesize = 48;
            };

            finder = {
              ShowPathbar = true;
              CreateDesktop = false;
              FXDefaultSearchScope = "SCcf";
              FXPreferredViewStyle = "clmv";
            };
          };

          keyboard = {
            enableKeyMapping = true;
            remapCapsLockToControl = true;
          };

          # ======================== DO NOT CHANGE THIS ========================
          stateVersion = 6;
          # ======================== DO NOT CHANGE THIS ========================
        };
      };
  };
}
