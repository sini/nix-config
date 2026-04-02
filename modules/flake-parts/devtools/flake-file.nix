{ inputs, ... }:
{
  imports = [
    (inputs.flake-file.flakeModules.dendritic or { })
    (inputs.den.flakeModules.dendritic or { })
  ];

  flake-file = {
    description = ''
      A NixOS flake describing homelab kubernetes nodes, kubernetes service deployments,
      mac laptop, desktop workstation, virtualized VFIO, and all manner of things compute.
    '';

    prune-lock.enable = true;

    nixConfig = {
      abort-on-warn = false;
      accept-flake-config = true;
      allow-import-from-derivation = true;
      auto-optimise-store = true;

      extra-substituters = [
        "https://nix-community.cachix.org"
        "https://install.determinate.systems"
      ];

      extra-trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
      ];

      extra-experimental-features = [
        "pipe-operator" # Lix uses this name
        "pipe-operators" # NixCpp uses this name
      ];

      extra-deprecated-features = [
        "or-as-identifier"
        "broken-string-escape"
      ];

      lazy-trees = true;
      submodules = true;
      use-xdg-base-directories = true;
    };

    inputs = {
      ayugram-desktop = {
        type = "git";
        submodules = true;
        url = "https://github.com/ndfined-crp/ayugram-desktop/";
        inputs = {
          flake-parts.follows = "flake-parts";
          nixpkgs.follows = "nixpkgs-unstable";
        };
      };

      betterfox = {
        url = "github:yokoffing/Betterfox";
        flake = false;
      };

      declarative-jellyfin = {
        url = "github:Sveske-Juice/declarative-jellyfin";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

      den.url = "github:vic/den";

      devshell = {
        url = "github:numtide/devshell";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

      disko = {
        url = "github:nix-community/disko";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

      files.url = "github:mightyiam/files";

      firefox-addons = {
        url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

      flake-compat = {
        url = "github:lix-project/flake-compat";
      };

      flake-file.url = "github:vic/flake-file";

      flake-parts = {
        url = "github:hercules-ci/flake-parts";
        inputs.nixpkgs-lib.follows = "nixpkgs-unstable";
      };

      flake-utils = {
        url = "github:numtide/flake-utils";
        inputs.systems.follows = "systems";
      };

      git-hooks-nix.url = "github:cachix/git-hooks.nix";

      haumea = {
        url = "github:nix-community/haumea/v0.2.2";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

      hm-wrapper-modules = {
        # Fork: custom features
        url = "github:sini/hm-wrapper-modules";
        inputs = {
          nixpkgs.follows = "nixpkgs-unstable";
          nix-wrapper-modules.follows = "nix-wrapper-modules";
          home-manager.follows = "home-manager-unstable";
        };
      };

      home-manager = {
        url = "github:nix-community/home-manager/release-25.11";
        inputs.nixpkgs.follows = "nixpkgs";
      };

      home-manager-master = {
        url = "github:nix-community/home-manager";
        inputs.nixpkgs.follows = "nixpkgs-master";
      };

      home-manager-stable-darwin = {
        url = "github:nix-community/home-manager/release-25.11";
        inputs.nixpkgs.follows = "nixpkgs-stable-darwin";
      };

      home-manager-unstable = {
        url = "github:nix-community/home-manager";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

      hyprland.url = "github:hyprwm/Hyprland";

      hyprland-plugins = {
        url = "github:hyprwm/hyprland-plugins";
        inputs.hyprland.follows = "hyprland";
      };

      hyprland-split-monitor-workspaces = {
        url = "github:Duckonaut/split-monitor-workspaces";
        inputs.hyprland.follows = "hyprland";
      };

      impermanence.url = "github:nix-community/impermanence";

      import-tree.url = "github:vic/import-tree";

      kubenix = {
        url = "github:pizzapim/kubenix";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

      lix = {
        url = "github:lix-project/lix";
        flake = false;
      };

      lix-module = {
        url = "git+https://git@git.lix.systems/lix-project/nixos-module";
        inputs = {
          nixpkgs.follows = "nixpkgs-unstable";
          lix.follows = "lix";
        };
      };

      microvm = {
        url = "github:microvm-nix/microvm.nix";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

      nix-ai-tools.url = "github:numtide/nix-ai-tools";

      nix-cachyos-kernel = {
        url = "github:xddxdd/nix-cachyos-kernel";
        inputs = {
          flake-parts.follows = "flake-parts";
          nixpkgs.follows = "nixpkgs-unstable";
        };
      };

      nix-darwin = {
        url = "github:LnL7/nix-darwin/nix-darwin-25.11";
        inputs.nixpkgs.follows = "nixpkgs";
      };

      nix-darwin-unstable = {
        url = "github:LnL7/nix-darwin";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

      nix-flatpak.url = "github:gmodena/nix-flatpak";

      nix-gaming = {
        url = "github:fufexan/nix-gaming";
        inputs = {
          flake-parts.follows = "flake-parts";
          nixpkgs.follows = "nixpkgs-unstable";
        };
      };

      nix-index-database = {
        url = "github:nix-community/nix-index-database";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

      nix-kube-generators.url = "github:farcaller/nix-kube-generators";

      nix-snapshotter = {
        url = "github:pdtpartners/nix-snapshotter";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

      nix-topology = {
        url = "github:oddlama/nix-topology";
        inputs = {
          flake-parts.follows = "flake-parts";
          nixpkgs.follows = "nixpkgs-unstable";
        };
      };

      nix-vscode-extensions = {
        url = "github:nix-community/nix-vscode-extensions";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

      nix-wrapper-modules = {
        url = "github:BirdeeHub/nix-wrapper-modules";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

      nixcord = {
        url = "github:kaylorben/nixcord";
        inputs = {
          flake-parts.follows = "flake-parts";
          nixpkgs.follows = "nixpkgs-unstable";
        };
      };

      nixhelm.url = "github:nix-community/nixhelm";

      nixidy = {
        # Fork: custom features
        url = "github:sini/nixidy";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

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

      nixos-facter-modules.url = "github:numtide/nixos-facter-modules";

      nixos-hardware.url = "github:nixos/nixos-hardware";

      nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

      nixpkgs-master.url = "github:nixos/nixpkgs/master";

      nixpkgs-stable-darwin.url = "github:nixos/nixpkgs/nixpkgs-25.11-darwin";

      nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

      nixpkgs-xr.url = "github:nix-community/nixpkgs-xr";

      niri.url = "github:sodiboo/niri-flake";

      nvf.url = "github:notashelf/nvf";

      pkgs-by-name-for-flake-parts.url = "github:drupol/pkgs-by-name-for-flake-parts";

      proton-cachyos.url = "github:powerofthe69/proton-cachyos-nix";

      razerdaemon = {
        # Fork: razer-control-revived
        url = "github:sini/razer-control-revived";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

      shimmer = {
        url = "github:nuclearcodecat/shimmer";
        flake = false;
      };

      spicetify-nix.url = "github:Gerg-L/spicetify-nix";

      statix = {
        url = "github:molybdenumsoftware/statix";
        inputs = {
          flake-parts.follows = "flake-parts";
          nixpkgs.follows = "nixpkgs-unstable";
        };
      };

      steam-config-nix = {
        url = "github:different-name/steam-config-nix";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

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

      zen-browser = {
        url = "github:0xc000022070/zen-browser-flake";
        inputs = {
          nixpkgs.follows = "nixpkgs-unstable";
          home-manager.follows = "home-manager-unstable";
        };
      };

      zjstatus.url = "github:dj95/zjstatus";
    };
  };
}
