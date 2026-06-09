{ inputs, ... }:
{
  flake-file.inputs.devshell = {
    url = "github:numtide/devshell";
    inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  imports = [
    inputs.devshell.flakeModule
  ];

  perSystem =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      devshells.default = {
        packages = [
          pkgs.git
          pkgs.gh
          pkgs.nix # Always use the nix version from this flake's nixpkgs version, so that nix-plugins (below) doesn't fail because of different nix versions.
          pkgs.nixos-rebuild # Ensure nixos-rebuild is available for darwin systems
          pkgs.nix-output-monitor
          pkgs.nix-fast-build
          pkgs.nil
          pkgs.nixd
          pkgs.sops
        ]
        ++ lib.optionals pkgs.stdenv.buildPlatform.isDarwin [
          pkgs.coreutils-full # Include GNU coreutils for darwin systems
        ];

        commands = [
          {
            package = config.packages.nix-flake-update;
            name = "nix-flake-update";
            help = "Update flake inputs with GitHub access token";
          }
          {
            package = config.packages.update-pkgs;
            name = "update-pkgs";
            help = "Update custom package sources via nix-update";
          }
          {
            package = pkgs.nh;
            help = "Nix helper for nixpkgs development";
          }
          {
            package = config.treefmt.build.wrapper;
            help = "Format all files";
          }
          {
            package = pkgs.nix-tree;
            help = "Interactively browse dependency graphs of Nix derivations";
          }
          {
            package = pkgs.nvd;
            help = "Diff two nix toplevels and show which packages were upgraded";
          }
          {
            package = pkgs.nix-diff;
            help = "Explain why two Nix derivations differ";
          }
          {
            package = pkgs.nix-output-monitor;
            help = "Nix Output Monitor (a drop-in alternative for `nix` which shows a build graph)";
          }
          {
            package = config.packages.list-infra;
            name = "list-infra";
            help = "List all flake environments and hosts with details";
          }
          {
            package = config.packages.nix-flake-build;
            name = "nix-flake-build";
            help = "Build a host configuration";
          }
          {
            package = config.packages.update-host-keys;
            name = "update-host-keys";
            help = "Collect and encrypt SSH host keys from all configured hosts";
          }
          {
            package = config.packages.nix-flake-provision-keys;
            name = "nix-flake-provision-keys";
            help = "Provision SSH host keys and disk encryption secrets for a NixOS host";
          }
          {
            package = config.packages.nix-flake-install;
            name = "nix-flake-install";
            help = "Install NixOS remotely using nixos-anywhere with SSH keys and disk encryption";
          }
          {
            package = config.packages.impermanence-copy;
            name = "impermanence-copy";
            help = "Copy existing data to impermanence persistent storage for a host";
          }
          {
            package = config.packages.update-tang-disk-keys;
            name = "update-tang-disk-keys";
            help = "Update disk encryption keys using Tang servers and TPM2";
          }
        ];

        devshell.startup.pre-commit.text = config.pre-commit.installationScript;
      };
    };
}
