{
  flake.hosts.patch = {
    system = "aarch64-darwin";

    environment = "dev";

    roles = [
      # "dev"
    ];

    extra-features = [ ];

    users = {
      sini = { };
    };

    systemConfiguration =
      { pkgs, ... }:
      {
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

        environment.systemPackages = with pkgs; [
          mosh
          age-plugin-yubikey
          ssh-to-pgp
          yj
          sops
          nix-fast-build
          iperf3
        ];

        users.users.sini = {
          description = "Jason Bowman";
          home = "/Users/sini";
        };
      };
  };
}
