{
  features.kube-helm.home =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        kubernetes-helm
        helmfile
        helm-ls
        helmsman
        kubernetes-helmPlugins.helm-cm-push
        kubernetes-helmPlugins.helm-diff
        kubernetes-helmPlugins.helm-s3
        kubernetes-helmPlugins.helm-git
        kubernetes-helmPlugins.helm-secrets
        nova
      ];
    };
}
