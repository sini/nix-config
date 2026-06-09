# K3s cluster bootstrap — oneshot systemd units that apply the generated
# manifests in dependency order on the initial node:
#   Wave -2: Cilium CNI + CoreDNS (networking first)
#   Wave -1: SOPS secrets operator + cert-manager, then ArgoCD
#
# Sub-aspect of k3s (which includes it). Recomputes the cluster context it needs
# (shouldInit, manifestPath) from the same collected k3s-nodes quirk the main
# aspect uses, so it stays a proper auto-imported module rather than a bare import.
{
  den,
  lib,
  config,
  self,
  ...
}:
let
  inherit (lib) mkIf getExe;
  clusters = config.den.clusters or { };
in
{
  den.aspects.services.k3s.bootstrap = {
    nixos =
      {
        k3s-nodes,
        config,
        pkgs,
        host,
        ...
      }:
      let
        clusterName = host.settings.services.k3s.clusterName;
        cluster = clusters.${clusterName};

        # Bootstrap only on the initial node (single declared cluster member)
        clusterNodes = lib.filter (n: n.clusterName == clusterName) k3s-nodes;
        shouldInit = (builtins.length clusterNodes) == 1;

        manifestBase = self + "/generated/manifests/${cluster.environment}-${clusterName}";
        manifestPath =
          name:
          builtins.path {
            path = manifestBase + "/${name}";
            name = "${clusterName}-${builtins.replaceStrings [ "/" "." ] [ "-" "-" ] name}";
          };
      in
      {
        systemd.services = {
          # Wave -2: Cilium CNI + CoreDNS (networking must come first)
          k3s-bootstrap-cilium = mkIf shouldInit {
            description = "Bootstrap Cilium CNI and CoreDNS";
            after = [ "k3s.service" ];
            requires = [ "k3s.service" ];
            path = [
              pkgs.kubectl
              pkgs.cilium-cli
            ];
            environment.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
            serviceConfig = {
              Type = "oneshot";
              ExecStart = pkgs.writeShellScript "k3s-bootstrap-cilium" ''
                set -e

                echo "Waiting for k3s API server..."
                until kubectl get nodes; do
                  sleep 5
                done

                if ${getExe pkgs.cilium-cli} --kubeconfig $KUBECONFIG status >/dev/null 2>&1; then
                  echo "Cilium already installed."
                  exit 0
                fi

                echo "Applying bootstrap resources..."
                ${getExe pkgs.kubectl} --kubeconfig $KUBECONFIG apply \
                  --server-side --force-conflicts \
                  -f ${manifestPath "bootstrap"} || true

                echo "Applying Cilium manifests..."
                ${getExe pkgs.kubectl} --kubeconfig $KUBECONFIG apply \
                  --server-side --force-conflicts \
                  -f ${manifestPath "cilium"} || true
                sleep 30

                echo "Applying CoreDNS manifests..."
                ${getExe pkgs.kubectl} --kubeconfig $KUBECONFIG apply \
                  --server-side --force-conflicts \
                  -f ${manifestPath "coredns"} || true
                sleep 30
              '';
            };
            wantedBy = [ "multi-user.target" ];
          };

          # Wave -1: SOPS secrets operator + cert-manager
          k3s-install-sops-secrets-operator = mkIf shouldInit {
            description = "Bootstrap SOPS secrets operator and cert-manager";
            after = [
              "k3s.service"
              "k3s-bootstrap-cilium.service"
            ];
            requires = [
              "k3s.service"
              "k3s-bootstrap-cilium.service"
            ];
            path = [ pkgs.kubectl ];
            environment.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
            serviceConfig = {
              Type = "oneshot";
              ExecStart = pkgs.writeShellScript "k3s-install-sops" ''
                set -e

                echo "Waiting for k3s API server..."
                until kubectl get nodes; do
                  sleep 5
                done

                if ! ${getExe pkgs.kubectl} --kubeconfig $KUBECONFIG get namespace sops-secrets-operator >/dev/null 2>&1; then
                  ${getExe pkgs.kubectl} --kubeconfig $KUBECONFIG create namespace sops-secrets-operator
                fi

                if ! ${getExe pkgs.kubectl} --kubeconfig $KUBECONFIG --namespace sops-secrets-operator get secret sops-age-key-file >/dev/null 2>&1; then
                  ${getExe pkgs.kubectl} --kubeconfig $KUBECONFIG create secret generic sops-age-key-file \
                    --namespace sops-secrets-operator \
                    --from-file=key=${config.age.secrets.kubernetes-sops-age-key.path}
                fi

                if ! ${getExe pkgs.kubectl} --kubeconfig $KUBECONFIG get deployment -n sops-secrets-operator sops-sops-secrets-operator >/dev/null 2>&1; then
                  ${getExe pkgs.kubectl} --kubeconfig $KUBECONFIG apply \
                    --server-side --force-conflicts \
                    -f ${manifestPath "sops-secrets-operator"}
                  sleep 30
                fi

                if ! ${getExe pkgs.kubectl} --kubeconfig $KUBECONFIG get deployment -n cert-manager cert-manager >/dev/null 2>&1; then
                  ${getExe pkgs.kubectl} --kubeconfig $KUBECONFIG apply \
                    --server-side --force-conflicts \
                    -f ${manifestPath "cert-manager"}
                  sleep 30
                fi
              '';
            };
            wantedBy = [ "multi-user.target" ];
          };

          # Wave -1: ArgoCD (depends on SOPS for secret decryption)
          k3s-install-argocd = mkIf shouldInit {
            description = "Bootstrap ArgoCD";
            after = [
              "k3s.service"
              "k3s-bootstrap-cilium.service"
              "k3s-install-sops-secrets-operator.service"
            ];
            requires = [
              "k3s.service"
              "k3s-bootstrap-cilium.service"
              "k3s-install-sops-secrets-operator.service"
            ];
            path = [ pkgs.kubectl ];
            environment.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
            serviceConfig = {
              Type = "oneshot";
              ExecStart = pkgs.writeShellScript "k3s-install-argocd" ''
                set -e

                echo "Waiting for k3s API server..."
                until kubectl get nodes; do
                  sleep 5
                done

                if ! ${getExe pkgs.kubectl} --kubeconfig $KUBECONFIG get namespace argocd >/dev/null 2>&1; then
                  ${getExe pkgs.kubectl} --kubeconfig $KUBECONFIG create namespace argocd
                fi

                if ! ${getExe pkgs.kubectl} --kubeconfig $KUBECONFIG get deployment -n argocd argocd-server >/dev/null 2>&1; then
                  ${getExe pkgs.kubectl} --kubeconfig $KUBECONFIG apply \
                    --server-side --force-conflicts \
                    -f ${manifestPath "argocd"}
                  ${getExe pkgs.kubectl} --kubeconfig $KUBECONFIG apply \
                    -f ${manifestPath "bootstrap.yaml"}
                fi
              '';
            };
            wantedBy = [ "multi-user.target" ];
          };
        };
      };
  };
}
