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
          pkgs.nix # Always use the nix version from this flake's nixpkgs version, so that nix-plugins (below) doesn't fail because of different nix versions.
          pkgs.nixos-rebuild # Ensure nixos-rebuild is available for darwin systems
          pkgs.nix-output-monitor
          pkgs.nil
          pkgs.nixd
          pkgs.nodePackages.prettier
        ]
        ++ lib.optionals pkgs.buildPlatform.isDarwin [
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
            package = pkgs.writeShellApplication {
              name = "build";
              text = ''
                set -euo pipefail
                [[ "$#" -ge 1 ]] \
                  || { echo "usage: build <HOST>..." >&2; exit 1; }
                HOSTS=()
                for h in "$@"; do
                  HOSTS+=(".#nixosConfigurations.$h.config.system.build.toplevel")
                done
                nom build --no-link --print-out-paths --show-trace "''${HOSTS[@]}"
              '';
            };
            help = "Build a host configuration";
          }
          {
            package = pkgs.writeShellApplication {
              name = "reset-axon";
              text = ''
                set -euo pipefail
                colmena exec --on axon-01,axon-02,axon-03 -- systemctl stop k3s containerd
                colmena exec --on axon-01,axon-02,axon-03 -- k3s-killall.sh
                colmena exec --on axon-01,axon-02,axon-03 -- rm -rf /etc/rancher/ /var/lib/rancher/ /var/lib/containerd/ /var/lib/kubelet/ /var/lib/cni/ /run/k3s/ /run/containerd/ /run/cni/ /opt/cni/ /opt/containerd/
                echo "Applying changes to axon-01..."
                colmena apply --on axon-01
                scp sini@axon-01:/etc/rancher/k3s/k3s.yaml /home/sini/.config/kube/config
                sed -i 's/127.0.0.1/axon-01/' /home/sini/.config/kube/config
                kubectl get nodes -o wide
                echo "Bringing up additional nodes..."
                colmena apply --on axon-02,axon-03
              '';
            };
            help = "Delete all k3s data and reset the cluster";
          }
        ];

        devshell.startup.pre-commit.text = config.pre-commit.installationScript;

        # env = [
        #   {
        #     # Additionally configure nix-plugins with our extra builtins file.
        #     # We need this for our repo secrets.
        #     name = "NIX_CONFIG";
        #     value = ''
        #       plugin-files = ${pkgs.nix-plugins}/lib/nix/plugins
        #       extra-builtins-file = ${./..}/nix/extra-builtins.nix
        #     '';
        #   }
        # ];
      };
    };
}
