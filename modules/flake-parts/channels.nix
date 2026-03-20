{ lib, inputs, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.channels = mkOption {
    type = types.attrsOf (
      types.submodule {
        options = {
          nixpkgs = mkOption {
            type = types.raw;
            description = "The nixpkgs flake input for this channel.";
          };
          home-manager = mkOption {
            type = types.raw;
            description = "The home-manager flake input for this channel.";
          };
          nix-darwin = mkOption {
            type = types.raw;
            description = "The nix-darwin flake input for this channel.";
          };
        };
      }
    );
    description = "Mapping of channel names to their nixpkgs, home-manager, and nix-darwin flake inputs.";
  };

  config.channels = {
    nixos-stable = {
      inherit (inputs) nixpkgs;
      inherit (inputs) home-manager;
      inherit (inputs) nix-darwin;
    };
    nixos-unstable = {
      nixpkgs = inputs.nixpkgs-unstable;
      home-manager = inputs.home-manager-unstable;
      nix-darwin = inputs.nix-darwin-unstable;
    };
    nixpkgs-master = {
      nixpkgs = inputs.nixpkgs-master;
      home-manager = inputs.home-manager-master;
      nix-darwin = inputs.nix-darwin-unstable;
    };
    nixpkgs-stable-darwin = {
      nixpkgs = inputs.nixpkgs-stable-darwin;
      home-manager = inputs.home-manager-stable-darwin;
      inherit (inputs) nix-darwin;
    };
    nix-darwin-unstable = {
      nixpkgs = inputs.nixpkgs-unstable;
      home-manager = inputs.home-manager-unstable;
      nix-darwin = inputs.nix-darwin-unstable;
    };
  };
}
