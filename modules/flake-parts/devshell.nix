# Based on https://github.com/oddlama/nix-config/blob/7e32b6d4d9b922892bcbf991902dd88a0c4a8fe7/nix/devshell.nix
{ inputs, ... }:
{
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
          pkgs.nil
          pkgs.nixd
          pkgs.nodePackages.prettier
          pkgs.sops
          pkgs.vals
        ]
        ++ lib.optionals pkgs.stdenv.buildPlatform.isDarwin [
          pkgs.coreutils-full # Include GNU coreutils for darwin systems
        ];

        commands = [
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
            package = config.packages.nix-flake-build;
            name = "nix-flake-build";
            help = "Build a host configuration";
          }
          {
            package = config.packages.nix-flake-update;
            name = "nix-flake-update";
            help = "Update flake inputs with GitHub access token";
          }
          {
            package = config.packages.reset-axon;
            name = "reset-axon";
            help = "Delete all k3s data and reset the cluster";
          }
          {
            package = config.packages.toggle-axon-kubernetes;
            name = "toggle-axon-kubernetes";
            help = "Toggle enable/disable Kubernetes on axon cluster nodes";
          }
          {
            package = config.packages.list-infra;
            name = "list-infra";
            help = "List all flake environments and hosts with details";
          }
          {
            package = config.packages.update-host-keys;
            name = "update-host-keys";
            help = "Collect and encrypt SSH host keys from all configured hosts";
          }
          {
            package = config.packages.update-tang-disk-keys;
            name = "update-tang-disk-keys";
            help = "Update disk encryption keys using Tang servers and TPM2";
          }
          {
            package = config.packages.generate-host-keys;
            name = "generate-host-keys";
            help = "Generate and encrypt SSH host keys for a new host";
          }
          {
            package = config.packages.nix-flake-install;
            name = "nix-flake-install";
            help = "Install NixOS remotely using nixos-anywhere with SSH keys and disk encryption";
          }
          {
            package = config.packages.generate-user-keys;
            name = "generate-user-keys";
            help = "Generate and encrypt ed25519 SSH keys for users";
          }
          {
            package = config.packages.generate-vault-certs;
            name = "generate-vault-certs";
            help = "Generate certificates for Vault raft cluster";
          }
          {
            package = config.packages.impermanence-copy;
            name = "impermanence-copy";
            help = "Copy existing data to impermanence persistent storage for a host";
          }
          {
            package = config.packages.k8s-update-manifests;
            name = "k8s-update-manifests";
            help = "Update Kubernetes manifests for nixidy environments";
          }
          {
            package = config.packages.convert-oidc-secrets;
            name = "convert-oidc-secrets";
            help = "Convert age-encrypted OIDC secrets to SOPS-encrypted YAML format";
          }
        ];

        devshell.startup.pre-commit.text = config.pre-commit.installationScript;

      };
    };
}
