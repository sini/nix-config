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

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      # Systems for which attributes of perSystem will be built. As
      # a rule of thumb, only systems provided by available hosts
      # should go in this list. More systems will increase evaluation
      # duration.
      systems = import inputs.systems;

      imports = [
        ./nix # Parts of the flake that are used to construct the final flake.
        ./hosts # Entrypoint for host configurations of my systems.
      ];
    };

  inputs = {
    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # global, so they can be `.follow`ed
    systems.url = "github:nix-systems/default";

    # Powered by
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    # NixPkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";

    # NixPkgs Unstable
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # Flatpak
    nix-flatpak.url = "github:gmodena/nix-flatpak";

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # macOS Support (master)
    nix-darwin = {
      # url = "github:lnl7/nix-darwin";
      url = "github:khaneliman/nix-darwin/spacer";
      # url = "git+file:///Users/khaneliman/github/nix-darwin";
      inputs.nixpkgs.follows = "unstable";
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
    # snowfall-lib = {
    #   url = "github:snowfallorg/lib";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    # # Snowfall Flake
    # # Simplified Nix Flakes on the command line.
    # snowfall-flake = {
    #   url = "github:snowfallorg/flake";
    #   inputs.nixpkgs.follows = "unstable";
    # };

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

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

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

    # Secure boot
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Facter - an alternative to nixos-generate-config
    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";

    # sops-nix - does not currently support nix-darwin, only home-manager... perhaps thats enough?
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

    # Global catppuccin theme
    catppuccin-cursors.url = "github:catppuccin/cursors";
    catppuccin.url = "github:catppuccin/nix";

    git-hooks-nix.url = "github:cachix/git-hooks.nix";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };
}
