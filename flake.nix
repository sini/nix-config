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
        ./parts/agenix-rekey.nix # Configuration for agenix-rekey + devshell
        ./parts/colmena.nix # Configuration for colmena remote deployment
        ./parts/devshell.nix # Configuration for nix develop shell.
        ./parts/fmt.nix # Configuration for treefmt.
        ./parts/pkgs.nix # Setup pkg overlays for various systems
        ./parts/systems.nix # Entrypoint for systems configurations.
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
      url = "github:khaneliman/nix-darwin/spacer";
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
    # nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";

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
  };
}
