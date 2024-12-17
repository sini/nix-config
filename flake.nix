#           ▜███▙       ▜███▙  ▟███▛
#            ▜███▙       ▜███▙▟███▛
#             ▜███▙       ▜██████▛
#      ▟█████████████████▙ ▜████▛     ▟▙
#     ▟███████████████████▙ ▜███▙    ▟██▙
#            ▄▄▄▄▖           ▜███▙  ▟███▛
#           ▟███▛             ▜██▛ ▟███▛
#          ▟███▛               ▜▛ ▟███▛
# ▟███████████▛                  ▟██████████▙
# ▜██████████▛                  ▟███████████▛
#       ▟███▛ ▟▙               ▟███▛
#      ▟███▛ ▟██▙             ▟███▛
#     ▟███▛  ▜███▙           ▝▀▀▀▀
#     ▜██▛    ▜███▙ ▜██████████████████▛
#      ▜▛     ▟████▙ ▜████████████████▛
#            ▟██████▙       ▜███▙
#           ▟███▛▜███▙       ▜███▙
#          ▟███▛  ▜███▙       ▜███▙
#          ▝▀▀▀    ▀▀▀▀▘       ▀▀▀▘
#
#
# 
{
  description = ''
  A NixOS flake based on snowfall-lib describing homelab kubernetes nodes, kubernetes 
service deployments, mac laptop, desktop workstation, virtualized VFIO, and all manner
of things compute.
'';

  inputs = {
    # NixPkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";

    # NixPkgs Unstable
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # Lix - https://lix.systems/add-to-config/
    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/2.91.1-2.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Flatpak
    nix-flatpak.url = "github:gmodena/nix-flatpak";

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # macOS Support
    # See: https://github.com/AlexNabokikh/nix-config/tree/master
    # https://github.com/rounakdatta/dotfiles
    # https://github.com/dustinlyons/nixos-config
    # https://github.com/srid/nixos-unified
    # https://github.com/clo4/nix-dotfiles
    # https://github.com/tbreslein/.dotfiles
    # https://github.com/khaneliman/khanelinix

    nix-darwin = { 
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Homebrew
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";

    # WSL
    # https://github.com/LGUG2Z/nixos-wsl-starter
    # https://github.com/khaneliman/khanelinix
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # Hardware Configuration
    nixos-hardware.url = "github:nixos/nixos-hardware";
    
    # Generate System Images
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nix Impermenance
    # See: https://nixos.wiki/wiki/Impermanence
    # https://grahamc.com/blog/erase-your-darlings/
    impermanence.url = "github:nix-community/impermanence";
    persist-retro.url = "github:Geometer1729/persist-retro";
    
    # Snowfall Lib
    # This config is based around this lib, and heavily inspired by the authors configs:
    # Plus Ultra: https://github.com/jakehamilton/config/tree/6158f53f916dc9522068aee3fdf7e14907045352
    # IogaMaster's flake: https://github.com/IogaMaster/dotfiles/tree/bd37e91d1c68a141701407f1dca903b03a6bd1a1
    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Snowfall Flake
    # Simplified Nix Flakes on the command line.
    snowfall-flake = {
			url = "github:snowfallorg/flake";
			inputs.nixpkgs.follows = "unstable";
		};

    # Snowfall Drift
    # Drift processes packages that contain an update attribute. To add an update script, specify a script derivation in the package's passthru.
    snowfall-drift = {
      url = "github:snowfallorg/drift";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # Snowfall Thaw
    # Semantic Versioning for Nix Flakes.
		snowfall-thaw = {
			url = "github:snowfallorg/thaw";
			inputs.nixpkgs.follows = "nixpkgs";
		};

    # Comma
    # Comma runs software without installing it.
    # Basically it just wraps together nix shell -c and nix-index. You stick a , in front of a command to run it from whatever location it happens to occupy in nixpkgs without really thinking about it.
    comma = {
      url = "github:nix-community/comma";
      inputs.nixpkgs.follows = "unstable";
    };

    # System Deployment
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # disko - Declarative disk partitioning
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # automatically generate infrastructure and network diagrams as SVGs directly from your NixOS configurations
    nix-topology.url = "github:oddlama/nix-topology";
    nix-topology.inputs.nixpkgs.follows = "nixpkgs";


    # Arion is a tool for building and running applications that consist of multiple docker containers using NixOS modules.
    # https://docs.hercules-ci.com/arion/
    arion = {
      url = "github:hercules-ci/arion";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    
    # A Nix Flake to build NixOS and run it on one of several Type-2 Hypervisors on NixOS/Linux.
    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # With flux you can build servers as packages with a simple interface and deploy them with the included module.
    # flux.url = "github:IogaMaster/flux";    

    # Run unpatched dynamically compiled binaries
    nix-ld = {
      url = "github:Mic92/nix-ld";
      inputs.nixpkgs.follows = "unstable";
    };

    # Neovim
    # TODO: Do my own neovim...
    neovim = {
      url = "github:jakehamilton/neovim";
      inputs.nixpkgs.follows = "unstable";
    };

    jeezyvim.url = "github:LGUG2Z/JeezyVim";

    # Tmux
    # TODO: Do my own tmux...
    tmux = {
      url = "github:jakehamilton/tmux";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        unstable.follows = "unstable";
      };
    };

    # Binary Cache
    attic = {
      url = "github:zhaofengli/attic";

      # FIXME: A specific version of Rust is needed right now or
      # the build fails. Re-enable this after some time has passed.
      inputs.nixpkgs.follows = "unstable";
      inputs.nixpkgs-stable.follows = "nixpkgs";
    };

    # https://github.com/nix-community/lanzaboote
    # nixos-anywhere

    # sops-nix - does not currently support nix-darwin, only home-manager... perhaps thats enough?
    # sops-nix = {
    #   url = "github:Mic92/sops-nix";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    # Agenix
    # https://lgug2z.com/articles/providing-runtime-secrets-to-nixos-services/
    # https://github.com/oddlama/agenix-rekey

    #  age.secrets.nix-access-tokens-github.file =
    #"${self}/secrets/root.nix-access-tokens-github.age";
    #nix.extraOptions = ''
    #!include ${config.age.secrets.nix-access-tokens-github.path}
    #'';


    # Vault Integration
    # The NixOS Vault Service module is a NixOS module that allows easily integrating Vault with existing systemd services.
    vault-service = {
      url = "github:DeterminateSystems/nixos-vault-service";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Yubikey Guide
    yubikey-guide = {
      url = "github:drduh/YubiKey-Guide";
      flake = false;
    };

    # GPG default configuration
    gpg-base-conf = {
      url = "github:drduh/config";
      flake = false;
    };
    
    # For nixd
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    

    ## Themes

    # Global catppuccin theme
    catppuccin.url = "github:catppuccin/nix";

    # NixOS Spicetify
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };


  };

  outputs =
    inputs:
    let
      lib = inputs.snowfall-lib.mkLib {
        # You must provide our flake inputs to Snowfall Lib.
        inherit inputs;

        # The `src` must be the root of the flake. See configuration
        # in the next section for information on how you can move your
        # Nix files to a separate directory.
        src = ./.;

        snowfall = {
          meta = {
            name = "shinjitsu";
            title = "shinjitsu";
          };

          namespace = "shinjitsu";
        };
      };
    in
    lib.mkFlake {
      inherit inputs;
      src = ./.;

      channels-config = {
        allowUnfree = true;
      };

      overlays = with inputs; [ ];

      systems.modules.nixos = with inputs; [ ];

      templates = import ./templates { };
    };
}
