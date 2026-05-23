_: {
  den.aspects.apps.kube-tools = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          # core
          pkgs.kubectl
          pkgs.kubecfg
          pkgs.kubectx
          pkgs.kubecolor
          pkgs.kconf
          pkgs.konf
          pkgs.kubecm
          pkgs.kubeswitch
          pkgs.kns

          # dev
          pkgs.devspace
          pkgs.kind
          pkgs.minikube
          pkgs.kops
          pkgs.kluctl
          pkgs.kompose
          pkgs.skaffold
          pkgs.tilt
          pkgs.kail
          pkgs.krane
          pkgs.kpt
          pkgs.kontemplate
          pkgs.timoni

          # helm
          pkgs.kubernetes-helm
          pkgs.helmfile
          pkgs.helm-ls
          pkgs.helmsman
          pkgs.kubernetes-helmPlugins.helm-cm-push
          pkgs.kubernetes-helmPlugins.helm-diff
          pkgs.kubernetes-helmPlugins.helm-s3
          pkgs.kubernetes-helmPlugins.helm-git
          pkgs.kubernetes-helmPlugins.helm-secrets
          pkgs.nova

          # observability
          pkgs.cilium-cli
          pkgs.hubble
          pkgs.stern
          pkgs.kubeshark
          pkgs.kubespy
          pkgs.kube-capacity
          pkgs.kube-linter
          pkgs.kubeconform
          pkgs.kubeval
          pkgs.datree
          pkgs.popeye
          pkgs.netassert
          pkgs.k8sgpt

          # plugins
          pkgs.krew
          pkgs.kubectl-klock
          pkgs.kubectl-tree
          pkgs.kubectl-node-shell
          pkgs.kubectl-images
          pkgs.kubectl-view-allocations
          pkgs.kubectl-view-secret
          pkgs.kubectl-evict-pod
          pkgs.kubectl-example
          pkgs.kubectl-convert
          pkgs.kubectl-doctor
          pkgs.rakkess
          pkgs.kfilt

          # security
          pkgs.kdigger
          pkgs.kube-bench
          pkgs.kube-score
          pkgs.kubeaudit
          pkgs.kubeclarity
          pkgs.kubesec
          pkgs.kubescape
          pkgs.kubeseal
          pkgs.kubernetes-polaris
          pkgs.karmor
          pkgs.kubestroyer
          pkgs.starboard
          pkgs.kyverno
          pkgs.terrascan
          pkgs.pinniped

          # tui
          pkgs.click
          pkgs.kubectl-explore
          pkgs.ktop
          pkgs.lens
          pkgs.kube-prompt

          # utils
          pkgs.clusterctl
          pkgs.cmctl
          pkgs.cri-tools
          pkgs.kubernetes-controller-tools
          pkgs.kubernetes-code-generator
          pkgs.kubernix
          pkgs.kubeone
          pkgs.kubelogin
          pkgs.kubelogin-oidc
          pkgs.kubetail
          pkgs.kubevirt
          pkgs.kustomize-sops
          pkgs.pgo-client
          pkgs.pv-migrate
          pkgs.talosctl
          pkgs.k2tf
          pkgs.kubergrunt
          pkgs.kubemqctl
          pkgs.krelay
          pkgs.ktunnel
          pkgs.kube-router
          pkgs.fetchit
        ];
      };
  };
}
