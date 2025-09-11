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
          inputs.nixidy.packages.${pkgs.system}.default
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
              name = "flake-update";
              text = ''
                # Check GitHub CLI auth status
                if ! gh auth status &>/dev/null; then
                  echo "GitHub CLI not authenticated. Logging in..."
                  gh auth login
                fi

                # Run flake update with the GitHub token
                nix flake update --option access-tokens "github.com=$(gh auth token)"
              '';
            };
            help = "Update flake inputs with GitHub access token";
          }
          {
            package = pkgs.writeShellApplication {
              name = "reset-axon";
              excludeShellChecks = [ "SC2016" ];
              text = ''
                colmena exec --on axon-01,axon-02,axon-03 -- systemctl stop k3s containerd
                colmena exec --on axon-01,axon-02,axon-03 -- k3s-killall.sh
                colmena exec --on axon-01,axon-02,axon-03 -- 'KUBELET_PATH=$(mount | grep kubelet | cut -d" " -f3) ''${KUBELET_PATH:+umount $KUBELET_PATH}'
                colmena exec --on axon-01,axon-02,axon-03 -- systemctl start containerd
                colmena exec --on axon-01,axon-02,axon-03 -- systemctl stop containerd
                colmena exec --on axon-01,axon-02,axon-03 -- rm -rf /etc/rancher/ /var/lib/rancher/ /var/lib/containerd/ /var/lib/kubelet/ /var/lib/cni/ /run/k3s/ /run/containerd/ /run/cni/ /opt/cni/ /opt/containerd/
                echo "Applying changes to axon-01..."
                colmena apply --on axon-01
                scp sini@axon-01:/etc/rancher/k3s/k3s.yaml "''${HOME}/.config/kube/config"
                sed -i 's/0.0.0.0/axon-01/' "''${HOME}/.config/kube/config"
                kubectl get nodes -o wide
                echo "Bringing up additional nodes..."
                colmena apply --on axon-02,axon-03
                kubectl get nodes -o wide
              '';
            };
            help = "Delete all k3s data and reset the cluster";
          }
          {
            package = pkgs.writeShellApplication {
              name = "render-nixidy";
              text = ''
                echo "Rendering nixidy manifests for prod cluster..."

                # Build nixidy manifests using inline expression
                nix build \
                  --impure \
                  --expr '
                  let
                    flake = builtins.getFlake (toString ./.);
                    pkgs = import flake.inputs.nixpkgs-unstable { system = "${pkgs.system}"; };
                    nixidyEnvs = flake.inputs.nixidy.lib.mkEnvs {
                      inherit pkgs;
                      envs = {
                        prod = {
                          modules = [
                            ./k8s/nixidy/environments/prod
                          ];
                        };
                      };
                    };
                  in
                  nixidyEnvs.prod.environmentPackage
                  ' \
                  --out-link k8s/nixidy/result

                # Create manifests directory
                mkdir -p k8s/nixidy/manifests/prod

                # Copy rendered manifests
                cp -r k8s/nixidy/result/* k8s/nixidy/manifests/prod/

                # Clean up symlink
                rm k8s/nixidy/result

                echo "Manifests rendered to k8s/nixidy/manifests/prod/"
                echo "Commit and push these manifests for ArgoCD to consume them."
              '';
            };
            help = "Render nixidy Kubernetes manifests";
          }
        ];

        devshell.startup.pre-commit.text = config.pre-commit.installationScript;

      };
    };
}
