{
  description = ''
    A NixOS flake describing homelab kubernetes nodes, kubernetes service deployments,
    mac laptop, desktop workstation, virtualized VFIO, and all manner of things compute.
  '';

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;

      imports = [
        ./flake-parts/agenix-rekey.nix # Configuration for agenix-rekey + devshell
        ./flake-parts/colmena.nix # Configuration for colmena remote deployment
        ./flake-parts/devshell.nix # Configuration for nix develop shell.
        ./flake-parts/fmt.nix # Configuration for treefmt.
        ./flake-parts/pkgs.nix # Setup pkg overlays for various systems
        ./flake-parts/systems.nix # Entrypoint for systems configurations.
      ];
    };

  inputs = {
    agenix = {
      url = "github:ryantm/agenix";
      inputs.home-manager.follows = "home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix-rekey = {
      url = "github:oddlama/agenix-rekey";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nix flake for "too much bleeding-edge" and unreleased packages (e.g., mesa_git, linux_cachyos, firefox_nightly, sway_git, gamescope_git). And experimental modules (e.g., HDR, duckdns).
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";

    colmena.url = "github:zhaofengli/colmena";

    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # disko - Declarative disk partitioning
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    git-hooks-nix.url = "github:cachix/git-hooks.nix";

    # Config is powered by this
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager-darwin = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    # macOS Support (master)
    nix-darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-24.11";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    nixos-anywhere = {
      url = "github:numtide/nixos-anywhere";
      inputs = {
        disko.follows = "disko";
        flake-parts.follows = "flake-parts";
        nixos-stable.follows = "nixpkgs";
        nixpkgs.follows = "nixpkgs";
        treefmt-nix.follows = "treefmt-nix";
      };
    };

    # Facter - an alternative to nixos-generate-config
    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";

    # Flatpak
    # nix-flatpak.url = "github:gmodena/nix-flatpak";

    # Homebrew
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    # automatically generate infrastructure and network diagrams as SVGs directly from your NixOS configurations
    nix-topology.url = "github:oddlama/nix-topology";
    nix-topology.inputs.nixpkgs.follows = "nixpkgs";

    # Generate System Images
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hardware Configuration
    nixos-hardware.url = "github:nixos/nixos-hardware";

    # Nixpkgs:
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";

    # NixPkgs - Darwin
    # NOTE: `darwin` indicates that this channel passes CI on macOS builders;
    # this should increase the binary cache hit rate, but may result in it
    # lagging behind the equivalent NixOS/Linux package set.
    nixpkgs-darwin.url = "github:nixos/nixpkgs/nixpkgs-24.11-darwin";

    # NixPkgs Unstable
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # global, so they can be `.follow`ed
    systems.url = "github:nix-systems/default";

    treefmt-nix.url = "github:numtide/treefmt-nix";

    # ucodenix delivers microcode updates for AMD CPUs on NixOS
    ucodenix = {
      url = "github:e-tho/ucodenix";
      # inputs.cpu-microcodes.follows = "ucodenix-cpu-microcodes";
    };

    # We pin to December 28th, 2024 since our older hardware hasn't recieved BIOS updates
    # addressing CVE-2024-56161. :(
    # ucodenix-cpu-microcodes = {
    #   url = "github:platomav/CPUMicrocodes/ec5200961ecdf78cf00e55d73902683e835edefd";
    #   flake = false;
    # };

  };
}
