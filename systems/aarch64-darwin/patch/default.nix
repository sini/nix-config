{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  networking.hostName = "patch";

  # environment.shells = [ pkgs.fish ];

  users.users.sini = {
    description = "Jason Bowman";
    home = "/Users/sini";
    # shell = pkgs.fish;
  };

  home-manager = {
    useUserPackages = true;
    useGlobalPkgs = true;
    users.sini = ../../../modules/home/home.nix;
    sharedModules = [ ];
    extraSpecialArgs = {
      inherit inputs;
    };
  };

  # This needs to be reapplied after system updates
  security.pam.enableSudoTouchIdAuth = true;

  # TODO: Should this be moved to the common config?
  services.nix-daemon.enable = true;

  # services.openssh.enable = true;
  # https://nixcademy.com/posts/macos-linux-builder/
  nix = {
    linux-builder = {
      enable = true;
      # ephemeral = false;
      maxJobs = 8;
      package = pkgs.darwin.linux-builder-x86_64;
    };

    nixPath = lib.mkForce [
      "nixpkgs=${inputs.nixpkgs}"
      "home-manager=${inputs.home-manager}"
    ];

    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # This seems to cause issues:
      # https://github.com/NixOS/nix/issues/7273
      #auto-optimise-store = true;
      trusted-substituters = [
        "https://helix.cachix.org"
        "https://cache.nixos.org"
      ];
      trusted-public-keys = [
        "helix.cachix.org-1:ejp9KQpR1FBI2onstMQ34yogDm4OgU2ru6lIwPvuCVs="
      ];
      trusted-users = [
        "root"
        "@admin"
      ];
    };

    # nix.registry = {
    #   # Latest nix-darwin breaks this and I can't be bothered to fix it right now
    #   # nixpkgs.flake = lib.mkForce inputs.nixpkgs-unstable;

    #   # inputs.self is a reference to this flake, which allows self-references.
    #   # In this case, adding this flake to the registry under the name `my`,
    #   # which is the name I use any time I'm customising stuff.
    #   # (at time of writing, this is only used for `nix flake init -t my#...`)
    #   # my.flake = inputs.self;

    #   # mkshell.flake = inputs.mkshell;
    # };

    channel.enable = false;

  };
  launchd.daemons.linux-builder = {
    serviceConfig = {
      StandardOutPath = "/var/log/darwin-builder.log";
      StandardErrorPath = "/var/log/darwin-builder.log";
    };
  };

  system = {
    defaults = {
      CustomUserPreferences = {
        NSGlobalDomain = {
          NSWindowShouldDragOnGesture = true;
        };
        "com.superultra.homerow" = {
          label-characters = "arstneiowfpluy";
          scroll-keys = "mnei";
          map-arrow-keys-to-scroll = false;
          launch-at-login = true;
          is-experimental-support-enabled = true;
          # The shortcut really is stored as the shift symbol and command symbol!
          non-search-shortcut = "⇧⌘Space";
        };
      };

      NSGlobalDomain = {
        # Automatic dark mode at night
        # AppleInterfaceStyleSwitchesAutomatically = true;

        # Disabling this means you can hold to repeat keys
        ApplePressAndHoldEnabled = false;

        # I *always* want to know the file type
        AppleShowAllExtensions = true;

        # I type fine anyway, stop getting in my way
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;

        # 15 milliseconds until the key repeats, then 2 milliseconds
        # between subsequent inputs. This can be achieved in the settings UI
        InitialKeyRepeat = 15;
        KeyRepeat = 2;

        # Enables using the function keys as the F<number> key instead of OS controls
        "com.apple.keyboard.fnState" = true;
      };

      # I don't change the speed because I think it's fine by default honestly.
      # Most of the time I don't use the dock anyway, instead just navigating with
      # Raycast and Homerow.
      dock.autohide = true;

      # Pretty sure this doesn't do anything anymore :(
      LaunchServices.LSQuarantine = false;

      finder = {
        # Shows a breadcrumb trail down the bottom of the Finder window
        ShowPathbar = true;

        # Hides desktop icons (but they're still accessible through Finder).
        # Because it never creates a desktop, you can't *click* on the desktop.
        CreateDesktop = false;

        # This magic string makes it search the current folder by default
        FXDefaultSearchScope = "SCcf";

        # Use the column view by default-- the obviously correct and best view
        FXPreferredViewStyle = "clmv";
      };
    };
    configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

  };

  environment.systemPackages = with pkgs; [
    mosh
    age-plugin-yubikey
    ssh-to-pgp
    yj
    sops
    nix-fast-build
    iperf3
    iperf
  ];

  nixpkgs.config = {
    allowUnfree = true;
  };

  # This needs to be set to get the default system-level fish configuration, such
  # as completions for Nix and related tools. This is also required because on macOS
  # the $PATH doesn't include all the entries it should by default.
  # programs.fish = {
  #   enable = true;
  #   useBabelfish = true;
  #   loginShellInit =
  #     let
  #       # We should probably use `config.environment.profiles`, as described in
  #       # https://github.com/LnL7/nix-darwin/issues/122#issuecomment-1659465635
  #       # but this takes into account the new XDG paths used when the nix
  #       # configuration has `use-xdg-base-directories` enabled. See:
  #       # https://github.com/LnL7/nix-darwin/issues/947 for more information.
  #       profiles = [
  #         "/etc/profiles/per-user/$USER" # Home manager packages
  #         "$HOME/.nix-profile"
  #         "(set -q XDG_STATE_HOME; and echo $XDG_STATE_HOME; or echo $HOME/.local/state)/nix/profile"
  #         "/run/current-system/sw"
  #         "/nix/var/nix/profiles/default"
  #       ];

  #       makeBinSearchPath = lib.concatMapStringsSep " " (path: "${path}/bin");
  #     in
  #     ''
  #       # Fix path that was re-ordered by Apple's path_helper
  #       fish_add_path --move --prepend --path ${makeBinSearchPath profiles}
  #       set fish_user_paths $fish_user_paths
  #     '';
  # };
  # ======================== DO NOT CHANGE THIS ========================
  system.stateVersion = 5;
  # ======================== DO NOT CHANGE THIS ========================
}
