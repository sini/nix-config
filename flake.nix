{
  description = ''
    A NixOS flake describing homelab kubernetes nodes, kubernetes service deployments,
    mac laptop, desktop workstation, virtualized VFIO, and all manner of things compute.
  '';

  nixConfig = {
    abort-on-warn = false;
    extra-experimental-features = [ "pipe-operators" ];
    # Stylix and Nixidy require this...
    allow-import-from-derivation = true; # https://nix.dev/manual/nix/2.26/language/import-from-derivation
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      text.readme.parts = {
        disallow-warnings =
          # markdown
          ''
            ## Trying to disallow warnings

            This at the top level of the `flake.nix` file:

            ```nix
            nixConfig.abort-on-warn = true;
            ```

            > [!NOTE]
            > It does not currently catch all warnings Nix can produce, but perhaps only evaluation warnings.

          '';

        automatic-import =
          # markdown
          ''
            ## Automatic import

            Nix files (they're all flake-parts modules) are automatically imported.
            Nix files prefixed with an underscore are ignored.
            No literal path imports are used.
            This means files can be moved around and nested in directories freely.

            > [!NOTE]
            > This pattern has been the inspiration of [an auto-imports library, import-tree](https://github.com/vic/import-tree).

          '';
      };
      imports = [ (inputs.import-tree ./modules) ];

      _module.args.rootPath = ./.;
    };

  inputs = {
    agenix = {
      url = "github:ryantm/agenix";
      inputs.home-manager.follows = "home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    agenix-rekey = {
      url = "github:oddlama/agenix-rekey";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    colmena = {
      url = "github:zhaofengli/colmena";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    declarative-jellyfin = {
      url = "github:Sveske-Juice/declarative-jellyfin";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    deploy-rs.url = "github:serokell/deploy-rs";

    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # disko - Declarative disk partitioning
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    git-hooks-nix.url = "github:cachix/git-hooks.nix";

    files.url = "github:mightyiam/files";

    # Config is powered by this
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs-unstable";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak"; # unstable branch. Use github:gmodena/nix-flatpak/?ref=<tag> to pin releases.

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager-unstable = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    import-tree.url = "github:vic/import-tree";

    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    nix-ai-tools.url = "github:numtide/nix-ai-tools";

    # GitKraken configuration
    nixkraken.url = "github:nicolas-goudry/nixkraken";

    nixos-anywhere = {
      url = "github:numtide/nixos-anywhere";
      inputs = {
        disko.follows = "disko";
        flake-parts.follows = "flake-parts";
        nixos-stable.follows = "nixpkgs";
        nixpkgs.follows = "nixpkgs-unstable";
        treefmt-nix.follows = "treefmt-nix";
      };
    };

    # Cachyos kernel
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
    proton-cachyos.url = "github:powerofthe69/proton-cachyos-nix";
    # TODO: deprecate...
    chaotic.url = "github:lonerOrz/nyx-loner"; # fork for compat

    # Facter - an alternative to nixos-generate-config
    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";

    # Flatpak
    # nix-flatpak.url = "github:gmodena/nix-flatpak";

    # Kubernetes GitOps with nix and Argo CD
    nixidy = {
      url = "github:arnarg/nixidy";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    nixhelm.url = "github:farcaller/nixhelm";

    hyprland.url = "github:hyprwm/Hyprland";

    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland"; # Prevents version mismatch.
    };

    hyprland-split-monitor-workspaces = {
      url = "github:Duckonaut/split-monitor-workspaces";
      inputs.hyprland.follows = "hyprland";
    };

    # hyprland-easymotion = {
    #   url = "github:zakk4223/hyprland-easymotion";
    #   inputs.hyprland.follows = "hyprland";
    # };

    impermanence.url = "github:nix-community/impermanence";

    kubenix = {
      url = "github:pizzapim/kubenix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    nix-snapshotter = {
      url = "github:pdtpartners/nix-snapshotter";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # automatically generate infrastructure and network diagrams as SVGs directly from your NixOS configurations
    nix-topology = {
      url = "github:oddlama/nix-topology";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # Discord extension for NixOS
    nixcord.url = "github:kaylorben/nixcord";

    # NixOS modules for gaming
    nix-gaming.url = "github:fufexan/nix-gaming";

    # Generate System Images
    # nixos-generators = {
    #   url = "github:nix-community/nixos-generators";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    # Hardware Configuration
    nixos-hardware.url = "github:nixos/nixos-hardware";

    # Nixpkgs:
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    # NixPkgs Unstable
    # nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable"; # Has binary cache + tests
    # nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable"; # Has binary cache
    nixpkgs-unstable.url = "github:nixos/nixpkgs/master"; # Bleeding edge...

    nvf.url = "github:notashelf/nvf";

    pkgs-by-name-for-flake-parts.url = "github:drupol/pkgs-by-name-for-flake-parts";

    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # global, so they can be `.follow`ed
    systems.url = "github:nix-systems/default";

    # styling
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";

    # Steam ricing
    # millennium.url = "git+https://github.com/SteamClientHomebrew/Millennium";

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    ucodenix = {
      url = "github:e-tho/ucodenix";
    };

    # vscode-server = {
    #   url = "github:nix-community/nixos-vscode-server";
    #   inputs.nixpkgs.follows = "nixpkgs-unstable";
    # };

    zjstatus.url = "github:dj95/zjstatus";

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs = {
        # IMPORTANT: we're using "libgbm" and is only available in unstable so ensure
        # to have it up-to-date or simply don't specify the nixpkgs input
        nixpkgs.follows = "nixpkgs-unstable";
        home-manager.follows = "home-manager-unstable";
      };
    };
    # Firefox extensions

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    shimmer = {
      url = "github:nuclearcodecat/shimmer";
      flake = false;
    };

    betterfox = {
      url = "github:yokoffing/Betterfox";
      flake = false;
    };

    # TODO: nix-darwin support if I ever use my macbook again...
    # NixPkgs - Darwin
    # NOTE: `darwin` indicates that this channel passes CI on macOS builders;
    # this should increase the binary cache hit rate, but may result in it
    # lagging behind the equivalent NixOS/Linux package set.
    # nixpkgs-darwin.url = "github:nixos/nixpkgs/nixpkgs-25.11-darwin";

    # home-manager-darwin = {
    #   url = "github:nix-community/home-manager/release-25.11";
    #   inputs.nixpkgs.follows = "nixpkgs-darwin";
    # };

    # macOS Support (master)
    # nix-darwin = {
    #   url = "github:LnL7/nix-darwin/nix-darwin-25.11";
    #   inputs.nixpkgs.follows = "nixpkgs-darwin";
    # };

    # Homebrew
    #nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";

    # homebrew-bundle = {
    #   url = "github:homebrew/homebrew-bundle";
    #   flake = false;
    # };

    # homebrew-core = {
    #   url = "github:homebrew/homebrew-core";
    #   flake = false;
    # };

    # homebrew-cask = {
    #   url = "github:homebrew/homebrew-cask";
    #   flake = false;
    # };

    niri.url = "github:sodiboo/niri-flake";

    # XR & Gaming stuff...
    # I know... I borrowed this from this cultured user and havent played with it: https://github.com/ToasterUwU/flake
    # buttplug-lite = {
    #   url = "github:runtime-shady-backroom/buttplug-lite";
    #   inputs.nixpkgs.follows = "nixpkgs-unstable";
    # };

    nixpkgs-xr.url = "github:nix-community/nixpkgs-xr";

    steam-config-nix = {
      url = "github:different-name/steam-config-nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    ayugram-desktop = {
      type = "git";
      submodules = true;
      url = "https://github.com/ndfined-crp/ayugram-desktop/";
    };
  };
}
